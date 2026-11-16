"""Run after a cold launch with Sandbox MCP only (no FlowMod or Wiremod)."""
import json,pathlib,sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'tools'))
from mcp_client import Client,ROOT
c=Client();checks=[];b=None
def check(n,v):assert v,n;checks.append(n);print('PASS',n,flush=True)
try:
    cat=c.call('sandbox_catalog',{'kind':'flowmod'})
    check('Missing optional FlowMod reported clearly',cat['installed'] is False and cat['total']==0)
    status=c.call('sandbox_status')
    check('Cold native session has neither FlowMod nor Wiremod',any(x['connected'] and not x['flowmod'] and not x['wiremod'] for x in status['instances']))
    before=c.call('sandbox_inspect',{'owned_only':True})['total']
    try:c.call('sandbox_create',{'name':'Missing FlowMod','entities':[{'label':'p','kind':'flowmod','flowmod':{'kind':'pump'}}]})
    except RuntimeError as e:check('Missing dependency returns actionable installation error','install it separately' in str(e))
    else:raise AssertionError('Missing addon creation should fail')
    check('Missing dependency leaves no partial build',c.call('sandbox_inspect',{'owned_only':True})['total']==before)
    b=c.call('sandbox_create',{'name':'Ordinary prop without FlowMod','origin':[400,500,-100],'entities':[{'label':'crate','model':'models/props_junk/wood_crate001a.mdl'}]})
    check('Ordinary prop creation remains available',len(b['entities'])==1 and 'flowmod' not in b['entities'][0])
finally:
    if b:c.call('sandbox_cleanup',{'build_id':b['build_id']})
    (ROOT/'artifacts/flowmod-absent-evaluation.json').write_text(json.dumps({'checks':checks,'transcript':c.transcript},indent=2),encoding='utf-8');c.close()
