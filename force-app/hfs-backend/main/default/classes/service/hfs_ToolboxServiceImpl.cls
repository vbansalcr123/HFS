/**
 * @description Implementation of hfs_ToolboxService. Owns the My Toolbox read
 * use cases and orchestrates the Selector layer through hfs_Application. Reads
 * only — no DML, so no Unit of Work / commitWork() is required. Per-source
 * resilience lives here: each count/list is wrapped in its own try/catch that
 * degrades to an UNAVAILABLE status DTO so one failing source never breaks the
 * whole group or leaks foreign data.
 */
public with sharing class hfs_ToolboxServiceImpl implements hfs_ToolboxService {
    /**
     * @description Return the running user's enrolled, active programs, ordered
     * by sort order. A query failure degrades the group to UNAVAILABLE.
     * @return A populated ProgramGroupDTO.
     */
    public hfs_ToolboxDTO.ProgramGroupDTO getMyPrograms() {
        hfs_ToolboxDTO.ProgramGroupDTO programGroup = new hfs_ToolboxDTO.ProgramGroupDTO();
        try {
            hfs_ProgramEnrolmentsSelector selector =
                (hfs_ProgramEnrolmentsSelector) hfs_Application.Selector.newInstance(
                    hfs_Program_Enrolment__c.SObjectType
                );
            List<hfs_Program_Enrolment__c> enrolments = selector.getProgramEnrolmentRecords(
                'hfs_Member__c = :memberId AND hfs_Status__c = :enrolledStatus ' +
                'AND hfs_Program__r.hfs_Active__c = true',
                new Map<String, Object>{
                    'memberId' => UserInfo.getUserId(),
                    'enrolledStatus' => 'Enrolled'
                }
            );
            for (hfs_Program_Enrolment__c enr : enrolments) {
                hfs_ToolboxDTO.ProgramDTO dto = new hfs_ToolboxDTO.ProgramDTO();
                dto.key = enr.hfs_Program__c;
                dto.label = enr.hfs_Program__r.Name;
                dto.icon = enr.hfs_Program__r.hfs_Icon__c;
                dto.destinationUrl = enr.hfs_Program__r.hfs_Destination_URL__c;
                programGroup.programs.add(dto);
            }
            programGroup.listStatus = hfs_ToolboxDTO.STATUS_AVAILABLE;
        } catch (Exception e) {
            programGroup.listStatus = hfs_ToolboxDTO.STATUS_UNAVAILABLE;
            programGroup.programs = new List<hfs_ToolboxDTO.ProgramDTO>();
        }
        return programGroup;
    }

    /**
     * @description Return the fixed, ordered Quick Actions list with resilient
     * per-source counts.
     * @return The ordered list of QuickActionDTO rows.
     */
    public List<hfs_ToolboxDTO.QuickActionDTO> getQuickActions() {
        List<hfs_ToolboxDTO.QuickActionDTO> actions = new List<hfs_ToolboxDTO.QuickActionDTO>();
        actions.add(buildFavouritesAction());
        actions.add(buildLinkWithUnavailableCount(
            'RECENT_DOWNLOADS', System.Label.hfs_Toolbox_Action_Recent_Downloads,
            'utility:download', '/recent-downloads'));
        actions.add(buildOrdersAction());
        actions.add(buildLinkWithUnavailableCount(
            'SAVED_SEARCHES', System.Label.hfs_Toolbox_Action_Saved_Searches,
            'utility:search', '/saved-searches'));
        actions.add(buildLinkAction(
            'SUBMIT_REQUEST', System.Label.hfs_Toolbox_Action_Submit_A_Request,
            'utility:new_window', '/submit-a-request'));
        return actions;
    }

    private hfs_ToolboxDTO.QuickActionDTO buildFavouritesAction() {
        hfs_ToolboxDTO.QuickActionDTO dto = new hfs_ToolboxDTO.QuickActionDTO();
        dto.key = 'MY_FAVOURITES';
        dto.label = System.Label.hfs_Toolbox_Action_My_Favourites;
        dto.icon = 'utility:favorite';
        dto.destinationUrl = '/my-favourites';
        dto.hasCount = true;
        try {
            hfs_FavouritesSelector selector =
                (hfs_FavouritesSelector) hfs_Application.Selector.newInstance(
                    hfs_Favorite__c.SObjectType
                );
            dto.count = selector.countFavouriteRecords(
                'OwnerId = :ownerId',
                new Map<String, Object>{ 'ownerId' => UserInfo.getUserId() }
            );
            dto.countStatus = hfs_ToolboxDTO.STATUS_AVAILABLE;
        } catch (Exception e) {
            dto.count = null;
            dto.countStatus = hfs_ToolboxDTO.STATUS_UNAVAILABLE;
        }
        return dto;
    }

    private hfs_ToolboxDTO.QuickActionDTO buildOrdersAction() {
        hfs_ToolboxDTO.QuickActionDTO dto = new hfs_ToolboxDTO.QuickActionDTO();
        dto.key = 'MY_ORDERS';
        dto.label = System.Label.hfs_Toolbox_Action_My_Orders;
        dto.icon = 'utility:cart';
        dto.destinationUrl = '/my-orders';
        dto.hasCount = true;
        try {
            hfs_OrdersSelector selector =
                (hfs_OrdersSelector) hfs_Application.Selector.newInstance(
                    Order.SObjectType
                );
            // Account-based sharing already scopes Order visibility to the user's
            // account; USER_MODE enforces CRUD/FLS. No extra owner filter needed.
            dto.count = selector.countOrderRecords('', new Map<String, Object>());
            dto.countStatus = hfs_ToolboxDTO.STATUS_AVAILABLE;
        } catch (Exception e) {
            dto.count = null;
            dto.countStatus = hfs_ToolboxDTO.STATUS_UNAVAILABLE;
        }
        return dto;
    }

    private hfs_ToolboxDTO.QuickActionDTO buildLinkWithUnavailableCount(
        String key, String label, String icon, String url
    ) {
        hfs_ToolboxDTO.QuickActionDTO dto = new hfs_ToolboxDTO.QuickActionDTO();
        dto.key = key;
        dto.label = label;
        dto.icon = icon;
        dto.destinationUrl = url;
        dto.hasCount = true;
        dto.count = null;
        dto.countStatus = hfs_ToolboxDTO.STATUS_UNAVAILABLE;
        return dto;
    }

    private hfs_ToolboxDTO.QuickActionDTO buildLinkAction(
        String key, String label, String icon, String url
    ) {
        hfs_ToolboxDTO.QuickActionDTO dto = new hfs_ToolboxDTO.QuickActionDTO();
        dto.key = key;
        dto.label = label;
        dto.icon = icon;
        dto.destinationUrl = url;
        dto.hasCount = false;
        dto.count = null;
        dto.countStatus = hfs_ToolboxDTO.STATUS_AVAILABLE;
        return dto;
    }
}