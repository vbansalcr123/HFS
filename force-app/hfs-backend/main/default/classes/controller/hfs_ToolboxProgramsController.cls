/**
 * @description Thin Controller for the My Toolbox "My Programs" group. Delegates
 * to hfs_ToolboxService (resolved through hfs_Application) and wraps the result
 * in hfs_Response. The Controller is the only door the LWC calls; it never
 * touches the Selector layer directly. Per-source resilience (list degrades to
 * UNAVAILABLE) is owned by the Service.
 */
public with sharing class hfs_ToolboxProgramsController {
    /**
     * @description Return the running user's enrolled programs.
     * @return hfs_Response whose payload is an hfs_ToolboxDTO.ProgramGroupDTO.
     */
    @AuraEnabled(cacheable=true)
    public static hfs_Response getMyPrograms() {
        try {
            hfs_ToolboxService service =
                (hfs_ToolboxService) hfs_Application.Service.newInstance(
                    hfs_ToolboxService.class
                );
            return hfs_Response.success(service.getMyPrograms());
        } catch (Exception e) {
            return hfs_Response.error(e);
        }
    }
}