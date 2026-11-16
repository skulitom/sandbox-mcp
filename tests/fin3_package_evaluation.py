"""Fresh-map checks for the packaged release, with Fin 3 present or absent."""
import json,pathlib,sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'tools'))
from mcp_client import Client,ROOT
c=Client(exe=ROOT/'release/sandbox-mcp-0.3.0-windows-x64/sandbox-mcp.exe')
present=sys.argv[1]=='present';checks=[];builds=[]
def check(n,v):assert v,n;checks.append(n);print('PASS',n,flush=True)
try:
    cat=c.call('sandbox_catalog',{'kind':'fin3'})
    check('Optional dependency discovery matches mounted addons',cat['installed']==present)
    if present:
        b=c.call('sandbox_blueprint',{'action':'load','name':'fin3-native-evaluation','origin':[0,0,-12150],'angles':[0,35,0]});builds.append(b['build_id'])
        e=c.call('sandbox_fin3_inspect',{'build_id':b['build_id']})['entities']
        fin=next(x['settings'] for x in e if x['settings']['kind']=='fin')
        prop=next(x['settings'] for x in e if x['settings']['kind']=='propeller')
        check('Saved wing settings survive game restart',fin['camber']==25)
        check('Saved propeller settings survive game restart',prop['pitch']==-20 and prop['blades']==3 and prop['invert'] and prop['diameter']==1.2)
        check('Blueprint restores frozen',all(x['physics']['frozen'] for x in b['entities']))
        b=c.call('sandbox_blueprint',{'action':'load','name':'mcp_fin3_glider','origin':[0,-400,-12150]});builds.append(b['build_id'])
        check('Saved aircraft restores all four aerodynamic surfaces',len([e for e in c.call('sandbox_fin3_inspect',{'build_id':b['build_id']})['entities'] if e['active']])==4)
    else:
        before=c.call('sandbox_inspect',{'owned_only':True})['total']
        try:c.call('sandbox_blueprint',{'action':'load','name':'mcp_fin3_glider','origin':[0,0,-12150]})
        except RuntimeError as ex:check('Missing dependency gives actionable error','3113528615' in str(ex))
        else:raise AssertionError('Loaded flight blueprint without dependency')
        check('Missing dependency leaves no partial build',c.call('sandbox_inspect',{'owned_only':True})['total']==before)
        b=c.call('sandbox_create',{'name':'Normal building without Fin','origin':[0,0,-12150],'entities':[{'label':'box','model':'models/props_junk/wood_crate001a.mdl'}]});builds.append(b['build_id'])
        check('Ordinary MCP construction remains usable',len(b['entities'])==1)
finally:
    for bid in builds:c.call('sandbox_cleanup',{'build_id':bid})
    (ROOT/('artifacts/fin3-package-'+sys.argv[1]+'.json')).write_text(json.dumps({'checks':checks,'transcript':c.transcript},indent=2),encoding='utf-8');c.close()
