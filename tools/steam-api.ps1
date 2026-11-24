# Original Steam API helper reused under MIT. Official installed SDK DLL.
Add-Type -TypeDefinition @'

using System;
using System.Text;
using System.Runtime.InteropServices;
public static class GModWorkshop {
    const string Dll = @"D:\Steam\steamapps\common\Half-Life 2\bin\steam_api.dll";
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] public static extern int SteamAPI_InitFlat(StringBuilder error);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] public static extern void SteamAPI_Shutdown();
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] public static extern void SteamAPI_RunCallbacks();
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] public static extern IntPtr SteamAPI_SteamUGC_v020();
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] public static extern IntPtr SteamAPI_SteamUtils_v010();
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] public static extern ulong SteamAPI_ISteamUGC_CreateItem(IntPtr self, uint app, int type);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] public static extern ulong SteamAPI_ISteamUGC_StartItemUpdate(IntPtr self, uint app, ulong item);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUGC_SetItemVisibility(IntPtr self, ulong update, int visibility);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl, CharSet=CharSet.Ansi)] [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUGC_SetItemTitle(IntPtr self, ulong update, string title);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl, CharSet=CharSet.Ansi)] [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUGC_SetItemDescription(IntPtr self, ulong update, [MarshalAs(UnmanagedType.LPUTF8Str)] string description);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl, CharSet=CharSet.Ansi)] [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUGC_SetItemContent(IntPtr self, ulong update, string folder);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl, CharSet=CharSet.Ansi)] [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUGC_SetItemPreview(IntPtr self, ulong update, string file);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl, CharSet=CharSet.Ansi)] [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUGC_AddItemPreviewFile(IntPtr self, ulong update, string file, int type);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl, CharSet=CharSet.Ansi)]
    public static extern ulong SteamAPI_ISteamUGC_SubmitItemUpdate(IntPtr self, ulong update, string note);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUtils_IsAPICallCompleted(IntPtr self, ulong call, [MarshalAs(UnmanagedType.I1)] out bool failed);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUtils_GetAPICallResult(IntPtr self, ulong call, [Out] byte[] result, int size, int callback, [MarshalAs(UnmanagedType.I1)] out bool failed);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] public static extern uint SteamAPI_ISteamUGC_GetItemState(IntPtr self, ulong item);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] public static extern ulong SteamAPI_ISteamUGC_SubscribeItem(IntPtr self, ulong item);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUGC_DownloadItem(IntPtr self, ulong item, [MarshalAs(UnmanagedType.I1)] bool priority);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUGC_GetItemInstallInfo(IntPtr self, ulong item, out ulong size, StringBuilder folder, uint capacity, out uint timestamp);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)]
    public static extern ulong SteamAPI_ISteamUGC_CreateQueryUGCDetailsRequest(IntPtr self, [In] ulong[] items, uint count);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUGC_SetReturnAdditionalPreviews(IntPtr self, ulong query, [MarshalAs(UnmanagedType.I1)] bool enabled);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] public static extern ulong SteamAPI_ISteamUGC_SendQueryUGCRequest(IntPtr self, ulong query);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] public static extern uint SteamAPI_ISteamUGC_GetQueryUGCNumAdditionalPreviews(IntPtr self, ulong query, uint index);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl, CharSet=CharSet.Ansi)] [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUGC_GetQueryUGCAdditionalPreview(IntPtr self, ulong query, uint index, uint preview, StringBuilder url, uint urlSize, StringBuilder name, uint nameSize, out int type);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUGC_ReleaseQueryUGCRequest(IntPtr self, ulong query);
}

[StructLayout(LayoutKind.Sequential)]
public struct GModTagArray { public IntPtr strings; public int count; }
public static class GModTags {
 [DllImport(@"D:\Steam\steamapps\common\Half-Life 2\bin\steam_api.dll", CallingConvention=CallingConvention.Cdecl)]
 [return: MarshalAs(UnmanagedType.I1)]
 static extern bool SteamAPI_ISteamUGC_SetItemTags(IntPtr self, ulong update, ref GModTagArray tags);
 public static bool Set(IntPtr self, ulong update, string[] tags) {
  IntPtr array=Marshal.AllocHGlobal(IntPtr.Size*tags.Length);
  var values=new IntPtr[tags.Length];
  try {
   for(int i=0;i<tags.Length;i++){values[i]=Marshal.StringToHGlobalAnsi(tags[i]);Marshal.WriteIntPtr(array,i*IntPtr.Size,values[i]);}
   var data=new GModTagArray{strings=array,count=tags.Length};
   return SteamAPI_ISteamUGC_SetItemTags(self,update,ref data);
  } finally { foreach(var p in values) if(p!=IntPtr.Zero) Marshal.FreeHGlobal(p); Marshal.FreeHGlobal(array); }
 }
}

'@
