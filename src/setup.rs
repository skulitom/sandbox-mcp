use crate::bridge::Bridge;
use anyhow::{Context, Result, bail, ensure};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::{
    fs,
    io::Read,
    path::{Path, PathBuf},
    time::{Duration, Instant},
};
use tiny_http::{Header, Method, Response, Server};

struct Profiles {
    home: PathBuf,
    roaming: PathBuf,
    local: PathBuf,
}
impl Profiles {
    fn new(root: Option<PathBuf>) -> Result<Self> {
        if let Some(root) = root {
            return Ok(Self {
                home: root.join("home"),
                roaming: root.join("roaming"),
                local: root.join("local"),
            });
        }
        Ok(Self {
            home: std::env::var_os("USERPROFILE")
                .context("USERPROFILE unavailable")?
                .into(),
            roaming: std::env::var_os("APPDATA")
                .context("APPDATA unavailable")?
                .into(),
            local: std::env::var_os("LOCALAPPDATA")
                .context("LOCALAPPDATA unavailable")?
                .into(),
        })
    }
    fn target(&self, client: &str) -> Result<PathBuf> {
        Ok(match client {
            "codex" => self.home.join(".codex/config.toml"),
            "claude" => self.roaming.join("Claude/claude_desktop_config.json"),
            "cursor" => self.home.join(".cursor/mcp.json"),
            "vscode" => self.roaming.join("Code/User/mcp.json"),
            "copilot" => self.home.join(".copilot/mcp-config.json"),
            _ => bail!("Unknown client. Choose one of the listed AI applications."),
        })
    }
}

fn config_entry(exe: &Path, game: Option<&Path>) -> Value {
    let mut args = vec![json!("serve")];
    if let Some(game) = game {
        args.push(json!("--game-dir"));
        args.push(json!(game));
    }
    json!({"command":exe,"args":args})
}
fn merge(client: &str, old: &str, entry: &Value, replace: bool) -> Result<String> {
    if client == "codex" {
        let mut doc = old
            .parse::<toml_edit::DocumentMut>()
            .context("Existing Codex config is invalid TOML; it was not changed")?;
        let existing = doc.get("mcp_servers").and_then(|v| v.get("sandbox-mcp"));
        if let Some(existing) = existing {
            let same_command =
                existing.get("command").and_then(|v| v.as_str()) == entry["command"].as_str();
            let same_args = existing
                .get("args")
                .and_then(|v| v.as_array())
                .is_some_and(|a| {
                    a.iter().map(|v| v.as_str()).eq(entry["args"]
                        .as_array()
                        .unwrap()
                        .iter()
                        .map(|v| v.as_str()))
                });
            if same_command && same_args {
                return Ok(old.into());
            }
            ensure!(
                replace,
                "Sandbox MCP already has a different configuration. Check 'Replace an existing Sandbox MCP entry' to update it; other entries remain unchanged."
            );
        }
        let mut array = toml_edit::Array::new();
        for arg in entry["args"].as_array().unwrap() {
            array.push(arg.as_str().context("Invalid command argument")?);
        }
        let mut table = toml_edit::Table::new();
        table["command"] =
            toml_edit::value(entry["command"].as_str().context("Invalid command path")?);
        table["args"] = toml_edit::value(array);
        if !doc.contains_key("mcp_servers") {
            doc["mcp_servers"] = toml_edit::Item::Table(toml_edit::Table::new());
        }
        doc["mcp_servers"]["sandbox-mcp"] = toml_edit::Item::Table(table);
        return Ok(doc.to_string());
    }
    let mut doc: Value = if old.trim().is_empty() {
        json!({})
    } else {
        serde_json::from_str(old).context("Existing client config is not plain JSON (it may contain comments). Nothing was changed. Use Copy configuration and merge the entry in your client's editor.")?
    };
    ensure!(
        doc.is_object(),
        "Client config must be a JSON object; nothing was changed"
    );
    let key = if client == "vscode" {
        "servers"
    } else {
        "mcpServers"
    };
    if doc.get(key).is_none() {
        doc[key] = json!({});
    }
    let servers = doc[key]
        .as_object_mut()
        .context("Existing server configuration is not an object; nothing was changed")?;
    let mut desired = entry.clone();
    if matches!(client, "vscode" | "cursor" | "copilot") {
        desired["type"] = json!("stdio");
    }
    if client == "copilot" {
        desired["tools"] = json!(["*"]);
    }
    if let Some(existing) = servers.get("sandbox-mcp") {
        if *existing == desired {
            return Ok(old.into());
        }
        ensure!(
            replace,
            "Sandbox MCP already has a different configuration. Check 'Replace an existing Sandbox MCP entry' to update it; other entries remain unchanged."
        );
    }
    servers.insert("sandbox-mcp".into(), desired);
    Ok(serde_json::to_string_pretty(&doc)? + "\n")
}
fn update_file(path: &Path, original: Option<&str>, updated: &str) -> Result<Option<PathBuf>> {
    if original == Some(updated) {
        return Ok(None);
    }
    let parent = path.parent().context("Invalid configuration path")?;
    fs::create_dir_all(parent)?;
    let current = match fs::read_to_string(path) {
        Ok(s) => Some(s),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => None,
        Err(e) => return Err(e.into()),
    };
    ensure!(
        current.as_deref() == original,
        "Configuration changed while setup was open. Retry to preserve your latest edits."
    );
    let id = uuid::Uuid::new_v4();
    let backup = if let Some(old) = original {
        let b = path.with_extension(format!("sandbox-mcp-{id}.bak"));
        fs::write(&b, old)?;
        Some(b)
    } else {
        None
    };
    let temp = path.with_extension(format!("sandbox-mcp-{id}.tmp"));
    fs::write(&temp, updated)?;
    if let Err(e) = fs::rename(&temp, path) {
        let _ = fs::remove_file(&temp);
        return Err(e).context("Could not replace the configuration; original is intact");
    }
    Ok(backup)
}

pub fn run(bridge: Bridge, profile_root: Option<PathBuf>, open_browser: bool) -> Result<()> {
    let profiles = Profiles::new(profile_root)?;
    let source = std::env::current_exe()?;
    let binary = fs::read(&source)?;
    let hash = format!("{:x}", Sha256::digest(&binary));
    let installed = profiles
        .local
        .join("SandboxMCP")
        .join(format!("{}-{}", env!("CARGO_PKG_VERSION"), &hash[..12]))
        .join("sandbox-mcp.exe");
    let entry = config_entry(&installed, bridge.game.as_deref());
    let server = Server::http("127.0.0.1:0")
        .map_err(|e| anyhow::anyhow!("Could not start local setup: {e}"))?;
    let address = server.server_addr().to_string();
    let secret = uuid::Uuid::new_v4().to_string();
    let prefix = format!("/{secret}/");
    let url = format!("http://{address}{prefix}");
    println!("{}", json!({"setup_url":url,"expires_in_seconds":900}));
    if open_browser {
        #[cfg(windows)]
        {
            use std::os::windows::process::CommandExt;
            std::process::Command::new("explorer.exe")
                .arg(&url)
                .creation_flags(0x08000000)
                .spawn()
                .context("Open setup in your browser")?;
        }
    }
    let started = Instant::now();
    while started.elapsed() < Duration::from_secs(900) {
        let Some(mut request) = server.recv_timeout(Duration::from_secs(1))? else {
            continue;
        };
        let host = request
            .headers()
            .iter()
            .find(|h| h.field.equiv("Host"))
            .map(|h| h.value.as_str());
        let origin = request
            .headers()
            .iter()
            .find(|h| h.field.equiv("Origin"))
            .map(|h| h.value.as_str().to_owned());
        let expected_origin = format!("http://{address}");
        let route = request.url().strip_prefix(&prefix).map(str::to_owned);
        if host != Some(address.as_str())
            || route.is_none()
            || origin.as_deref().is_some_and(|v| v != expected_origin)
        {
            let _ = request.respond(Response::from_string("Forbidden").with_status_code(403));
            continue;
        }
        let route = route.unwrap();
        let is_get = *request.method() == Method::Get;
        let mut close = false;
        let (mime, result): (&str, Result<String>) = if is_get && route.is_empty() {
            (
                "text/html; charset=utf-8",
                Ok(include_str!("setup.html").into()),
            )
        } else if is_get && route == "api/state" {
            let clients: Vec<_> = [
                ("codex", "Codex"),
                ("claude", "Claude Desktop"),
                ("cursor", "Cursor"),
                ("copilot", "GitHub Copilot / VS Code"),
                ("vscode", "VS Code (legacy Local harness)"),
            ]
            .into_iter()
            .map(|(id, label)| {
                let path = profiles.target(id).unwrap();
                json!({"id":id,"label":label,"path":path,"exists":path.exists()})
            })
            .collect();
            let status = bridge
                .status()
                .unwrap_or_else(|e| json!({"error":format!("{e:#}")}));
            ("application/json",Ok(json!({"version":env!("CARGO_PKG_VERSION"),"clients":clients,"entry":config_entry(&source,bridge.game.as_deref()),"installed_path":installed,"game":status}).to_string()))
        } else if *request.method() == Method::Post && route == "api/install" {
            let result = (|| -> Result<String> {
                ensure!(
                    origin.as_deref() == Some(expected_origin.as_str()),
                    "Installation requires a same-origin setup page"
                );
                let mut body = String::new();
                request.as_reader().take(8193).read_to_string(&mut body)?;
                ensure!(body.len() <= 8192, "Setup request too large");
                let data: Value = serde_json::from_str(&body)?;
                let client = data["client"].as_str().context("Choose an AI client")?;
                let target = profiles.target(client)?;
                if target.exists() {
                    ensure!(
                        fs::metadata(&target)?.len() <= 1048576,
                        "Configuration exceeds 1 MiB; merge the entry manually"
                    );
                }
                let old = match fs::read_to_string(&target) {
                    Ok(s) => Some(s),
                    Err(e) if e.kind() == std::io::ErrorKind::NotFound => None,
                    Err(e) => return Err(e.into()),
                };
                let updated = merge(
                    client,
                    old.as_deref().unwrap_or(""),
                    &entry,
                    data["replace"] == true,
                )?;
                fs::create_dir_all(installed.parent().unwrap())?;
                if !installed.exists() {
                    fs::write(&installed, &binary)?;
                } else {
                    ensure!(
                        fs::read(&installed)? == binary,
                        "Installed companion does not match this release"
                    );
                }
                let backup = update_file(&target, old.as_deref(), &updated)?;
                Ok(json!({"ok":true,"path":target,"backup":backup,"installed_path":installed,"next":"Restart your AI app, approve the Sandbox MCP connection there, then click Connect in GMod's Utilities tab."}).to_string())
            })();
            ("application/json", result)
        } else if *request.method() == Method::Post
            && route == "api/close"
            && origin.as_deref() == Some(expected_origin.as_str())
        {
            close = true;
            ("application/json", Ok(json!({"ok":true}).to_string()))
        } else {
            (
                "application/json",
                Err(anyhow::anyhow!("Unknown setup route")),
            )
        };
        let (status, body) = match result {
            Ok(body) => (200, body),
            Err(e) => (400, json!({"error":format!("{e:#}")}).to_string()),
        };
        let mut response = Response::from_string(body).with_status_code(status);
        for (key, value) in [
            ("Content-Type", mime),
            ("Cache-Control", "no-store"),
            ("X-Content-Type-Options", "nosniff"),
            ("Referrer-Policy", "no-referrer"),
            (
                "Content-Security-Policy",
                "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'",
            ),
        ] {
            response.add_header(Header::from_bytes(key, value).unwrap());
        }
        let _ = request.respond(response);
        if close {
            break;
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn json_preserves_unrelated_settings() {
        let entry = json!({"command":"C:\\Apps\\sandbox-mcp.exe","args":["serve"]});
        let old = r#"{"theme":"dark","mcpServers":{"other":{"command":"other","env":{"SECRET":"unchanged"}}}}"#;
        let output = merge("claude", old, &entry, false).unwrap();
        let result: Value = serde_json::from_str(&output).unwrap();
        let original: Value = serde_json::from_str(old).unwrap();
        assert_eq!(result["theme"], original["theme"]);
        assert_eq!(
            result["mcpServers"]["other"],
            original["mcpServers"]["other"]
        );
        assert_eq!(merge("claude", &output, &entry, false).unwrap(), output);
        assert!(
            merge(
                "claude",
                &output,
                &json!({"command":"different","args":[]}),
                false
            )
            .is_err()
        );
    }
    #[test]
    fn toml_preserves_comments_and_other_servers() {
        let old = "# keep this comment\nmodel = 'example'\n[mcp_servers.other]\ncommand='other'\n";
        let entry = json!({"command":"C:\\Apps\\sandbox-mcp.exe","args":["serve"]});
        let output = merge("codex", old, &entry, false).unwrap();
        assert!(output.contains("# keep this comment"));
        let parsed = output.parse::<toml_edit::DocumentMut>().unwrap();
        assert_eq!(
            parsed["mcp_servers"]["other"]["command"].as_str(),
            Some("other")
        );
        assert_eq!(merge("codex", &output, &entry, false).unwrap(), output);
    }
    #[test]
    fn malformed_configs_fail_without_replacement() {
        let entry = json!({"command":"x","args":[]});
        for text in ["[]", "{oops}", "{\"servers\":true}", "// comments\n{}"] {
            assert!(merge("vscode", text, &entry, false).is_err());
        }
    }
    #[test]
    fn vscode_uses_its_own_schema() {
        let entry = json!({"command":"x","args":["serve"]});
        let v: Value = serde_json::from_str(&merge("vscode", "", &entry, false).unwrap()).unwrap();
        assert_eq!(v["servers"]["sandbox-mcp"]["type"], "stdio");
        assert!(v.get("mcpServers").is_none());
    }
}
