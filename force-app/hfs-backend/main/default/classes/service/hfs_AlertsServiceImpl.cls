/**
 * @description Implementation of hfs_AlertsService. Use-case boundary for "get my unread alert
 * count" for the global-header badge. Read-only (no commitWork). Builds the WHERE clause + bind
 * map and delegates to the shared hfs_AlertsSelector's resilient count method, which runs
 * WITH USER_MODE so the count is scoped to the running user's own data.
 *
 * The unread-count data model (hfs_Alert_Dismissal__c plus the additional hfs_Alert__c fields)
 * is owned by HFS-41 and is only partially built in this org today. When those fields/objects
 * are absent the selector's dynamic query throws; that exception propagates to the Controller,
 * which translates it into an UNAVAILABLE badge state. This impl therefore returns only the
 * COUNT case; the UNAVAILABLE case is produced by the Controller's catch.
 */
public inherited sharing class hfs_AlertsServiceImpl implements hfs_AlertsService {
    /**
     * @description Return the running user's own unread-alert count. Active alerts within the
     * current date window and matching the user's audience, minus those the user has dismissed.
     * @param userId the running user's Id
     * @return an hfs_AlertsBadgeDTO with status COUNT and the unread count
     */
    public hfs_AlertsBadgeDTO getUnreadAlertCount(Id userId) {
        hfs_AlertsSelector selector = (hfs_AlertsSelector) hfs_Application.Selector.newInstance(
            hfs_Alert__c.SObjectType
        );
        Integer count = selector.countUnreadForUser(userId);
        return new hfs_AlertsBadgeDTO(hfs_AlertsBadgeDTO.STATUS_COUNT, count);
    }
}