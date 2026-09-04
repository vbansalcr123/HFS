/**
 * @description Thin Controller for the My Toolbox Quick Actions group. Delegates
 * to hfs_ToolboxService (resolved through hfs_Application) and wraps the result
 * in hfs_Response. The Controller is the only door the LWC calls; it never
 * touches the Selector layer directly. Resilient per-source counts are owned by
 * the Service.
 */
public with sharing class hfs_ToolboxQuickActionsController {
    /**
     * @description Return the ordered Quick Actions list for the running user.
     * @return hfs_Response whose payload is a List&lt;hfs_ToolboxDTO.QuickActionDTO&gt;.
     */
    @AuraEnabled(cacheable=true)
    public static hfs_Response getQuickActions() {
        try {
            hfs_ToolboxService service =
                (hfs_ToolboxService) hfs_Application.Service.newInstance(
                    hfs_ToolboxService.class
                );
            return hfs_Response.success(service.getQuickActions());
        } catch (Exception e) {
            return hfs_Response.error(e);
        }
    }
}