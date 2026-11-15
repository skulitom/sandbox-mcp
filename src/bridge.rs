use anyhow::{Context, Result, bail, ensure};
use base64::{Engine, engine::general_purpose::STANDARD};
use serde_json::{Value, json};
use std::{
    path::PathBuf,
    time::{Duration, SystemTime, UNIX_EPOCH},
};

#[derive(Clone)]
pub struct Bridge {
    pub game: Option<PathBuf>,
    pub instance: Option<String>,
}

fn now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}
fn identifier(s: &str) -> bool {
    !s.is_empty() && s.len() <= 64 && s.bytes().all(|b| b.is_ascii_hexdigit() || b == b'-')
}

pub fn discover_game(explicit: Option<PathBuf>) -> Option<PathBuf> {
    if let Some(p) =
        explicit.or_else(|| std::env::var_os("SANDBOX_MCP_GAME_DIR").map(PathBuf::from))
    {
        return Some(p);
    }
    let mut roots: Vec<PathBuf> = [
        "C:\\Program Files (x86)\\Steam",
        "C:\\Program Files\\Steam",
        "D:\\Steam",
        "E:\\Steam",
    ]
    .iter()
    .map(PathBuf::from)
    .collect();
    if let Ok(output) = std::process::Command::new("reg")
        .args(["query", "HKCU\\Software\\Valve\\Steam", "/v", "SteamPath"])
        .output()
    {
        let text = String::from_utf8_lossy(&output.stdout);
        for line in text.lines() {
            if let Some((_, p)) = line.split_once("REG_SZ") {
                roots.push(PathBuf::from(p.trim()));
            }
        }
    }
    for root in roots.clone() {
        if let Ok(vdf) = std::fs::read_to_string(root.join("steamapps/libraryfolders.vdf")) {
            for line in vdf.lines() {
                let parts: Vec<_> = line.split('"').collect();
                if parts.len() >= 4 && parts[1] == "path" {
                    roots.push(PathBuf::from(parts[3].replace("\\\\", "\\")));
                }
            }
        }
    }
    roots
        .into_iter()
        .map(|p| p.join("steamapps/common/GarrysMod/garrysmod"))
        .find(|p| p.join("gameinfo.txt").exists())
}

impl Bridge {
    fn root(&self) -> Result<PathBuf> {
        Ok(self
            .game
            .as_ref()
            .context(
                "Garry's Mod was not found. Use --game-dir with the installed garrysmod folder.",
            )?
            .join("data/sandbox_mcp/instances"))
    }
    fn instances(&self) -> Result<Vec<(PathBuf, Value)>> {
        let root = self.root()?;
        let mut found = Vec::new();
        if !root.exists() {
            return Ok(found);
        }
        for entry in std::fs::read_dir(root)?.flatten().take(4096) {
            if !entry.file_type()?.is_dir() {
                continue;
            }
            let name = entry.file_name().to_string_lossy().to_string();
            if !identifier(&name) {
                continue;
            }
            if let Ok(bytes) = std::fs::read(entry.path().join("status.json")) {
                if bytes.len() > 16384 {
                    continue;
                }
                if let Ok(v) = serde_json::from_slice::<Value>(&bytes)
                    && now().abs_diff(v["heartbeat"].as_u64().unwrap_or(0)) <= 12
                {
                    found.push((entry.path(), v));
                }
            }
        }
        found.sort_by(|a, b| a.0.cmp(&b.0));
        Ok(found)
    }
    pub fn status(&self) -> Result<Value> {
        let instances: Vec<_> = self.instances()?.into_iter().map(|(_, v)| v).collect();
        Ok(
            json!({"version":env!("CARGO_PKG_VERSION"),"game_dir":self.game,"instances":instances,
            "help":"Start a Sandbox map with the Workshop addon, unpause, then Q > Utilities > Sandbox MCP > Connect. If multiple games are open, pass --instance ID to the companion. No instance means the game is stopped, paused, or the addon is not installed."}),
        )
    }
    async fn selected(&self) -> Result<(PathBuf, Value, String)> {
        let mut candidates: Vec<_> = self
            .instances()?
            .into_iter()
            .filter(|(_, v)| {
                self.instance
                    .as_ref()
                    .is_none_or(|id| v["instance"].as_str() == Some(id))
            })
            .collect();
        ensure!(
            !candidates.is_empty(),
            "No live game session. Start a Sandbox map, unpause, and click Q > Utilities > Sandbox MCP > Connect. Use sandbox_status for diagnostics."
        );
        ensure!(
            candidates.len() == 1,
            "Multiple live game sessions. Select one explicitly with --instance ID (listed by sandbox_status)."
        );
        let (path, status) = candidates.remove(0);
        ensure!(
            status["connected"] == true,
            "Game session is disconnected. The host must click Q > Utilities > Sandbox MCP > Connect."
        );
        let auth: Value = serde_json::from_slice(
            &tokio::fs::read(path.join("auth.json"))
                .await
                .context("Connection changed. Reconnect in-game.")?,
        )?;
        let token = auth["token"]
            .as_str()
            .context("Missing connection token. Reconnect in-game.")?
            .to_owned();
        Ok((path, status, token))
    }
    pub async fn call(&self, tool: &str, args: Value) -> Result<Value> {
        let (path, status, token) = self.selected().await?;
        let id = uuid::Uuid::new_v4().to_string();
        let packet = json!({"id":id,"instance":status["instance"],"token":token,"expires":now()+25,"tool":tool,"args":args});
        let bytes = serde_json::to_vec(&packet)?;
        ensure!(
            bytes.len() <= 262144,
            "Request exceeds 256 KiB; split the scene into smaller batches."
        );
        let temp = path.join("requests").join(format!("{id}.tmp"));
        let request = path.join("requests").join(format!("{id}.json"));
        tokio::fs::write(&temp, bytes)
            .await
            .context("Cannot write game request")?;
        tokio::fs::rename(temp, &request).await?;
        let response = path.join("responses").join(format!("{id}.json"));
        let started = tokio::time::Instant::now();
        while started.elapsed() < Duration::from_secs(28) {
            if let Ok(bytes) = tokio::fs::read(&response).await {
                ensure!(bytes.len() <= 1048576, "Game response exceeds 1 MiB");
                let result: Value =
                    serde_json::from_slice(&bytes).context("Invalid game response")?;
                let _ = tokio::fs::remove_file(&response).await;
                if result["ok"] != true {
                    bail!(
                        "{}",
                        result["error"].as_str().unwrap_or("Game command failed")
                    );
                }
                let mut value = result["data"].clone();
                if let Some(filename) = value
                    .get("image_file")
                    .and_then(Value::as_str)
                    .map(String::from)
                {
                    ensure!(
                        filename == format!("{id}.jpg"),
                        "Invalid screenshot filename from game"
                    );
                    let image = path.join("responses").join(filename);
                    let bytes = tokio::fs::read(&image).await?;
                    ensure!(bytes.len() <= 4 * 1024 * 1024, "Screenshot exceeds 4 MiB");
                    let _ = tokio::fs::remove_file(image).await;
                    value["_image_base64"] = Value::String(STANDARD.encode(bytes));
                }
                value["request_id"] = id.into();
                value["elapsed_ms"] = (started.elapsed().as_millis() as u64).into();
                return Ok(value);
            }
            tokio::time::sleep(Duration::from_millis(60)).await;
        }
        let _ = tokio::fs::remove_file(request).await;
        bail!(
            "Game request {id} timed out. Unpause the game and check sandbox_status. A mutation might already have run: inspect the scene or sandbox_events before retrying."
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn identifiers_reject_paths() {
        assert!(identifier("abc-123"));
        for s in ["", "..", "../abc", "abc/def", "C:\\x"] {
            assert!(!identifier(s));
        }
    }
}
