/**
 * @description Controller for the My Toolbox "Account" group. Returns the three
 * Account links (My Profile, My Station Info, Settings) as pure link metadata.
 * Read-only; no writes.
 */
public with sharing class hfs_ToolboxAccountController {
    /**
     * @description Return the Account group links for the running user.
     * @return hfs_Response whose payload is a List&lt;hfs_ToolboxDTO.AccountLinkDTO&gt;.
     */
    @AuraEnabled(cacheable=true)
    public static hfs_Response getAccountLinks() {
        try {
            List<hfs_ToolboxDTO.AccountLinkDTO> links = new List<hfs_ToolboxDTO.AccountLinkDTO>();
            links.add(buildLink(System.Label.hfs_Toolbox_Account_My_Profile,
                'utility:user', '/my-profile'));
            links.add(buildLink(System.Label.hfs_Toolbox_Account_My_Station_Info,
                'utility:company', '/my-station-info'));
            links.add(buildLink(System.Label.hfs_Toolbox_Account_Settings,
                'utility:settings', '/settings'));
            return hfs_Response.success(links);
        } catch (Exception e) {
            return hfs_Response.error(e);
        }
    }

    private static hfs_ToolboxDTO.AccountLinkDTO buildLink(
        String label, String icon, String url
    ) {
        hfs_ToolboxDTO.AccountLinkDTO dto = new hfs_ToolboxDTO.AccountLinkDTO();
        dto.key = url;
        dto.label = label;
        dto.icon = icon;
        dto.destinationUrl = url;
        return dto;
    }
}