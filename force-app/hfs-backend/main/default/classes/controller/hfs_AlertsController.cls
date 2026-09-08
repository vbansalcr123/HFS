/**
 * @description Controller for the global-header alerts badge (hfs_alertsBadge). It is the only
 * door the LWC calls. Exposes a single cacheable read for the running user's own unread-alert
 * count. Thin by design: delegates to hfs_AlertsService (resolved through hfs_Application),
 * wraps success in hfs_Response.success(dto) and any exception in hfs_Response.error(...).
 *
 * Because the unread-count data model (hfs_Alert_Dismissal__c plus additional hfs_Alert__c
 * fields) is owned by HFS-41 and only partially built in this org today, the underlying query
 * throws when those fields/objects are absent. This controller catches at the boundary and
 * returns an error response so the badge renders its UNAVAILABLE state (never 0, never a stale
 * or another user's count) while the header still renders fully.
 */
public with sharing class hfs_AlertsController {
    /** Domain fallback code for unexpected (non-business) errors. */
    @TestVisible
    private static final String FALLBACK_CODE = 'ALERTS_UNAVAILABLE';

    /**
     * @description Test seam. When true (only settable in a test context), the read path throws
     * so the resilience catch branch can be covered deterministically even if the org happens to
     * carry the upstream fields.
     */
    @TestVisible
    private static Boolean forceFailure = false;

    /**
     * @description Return the running user's own unread-alert count for the header badge.
     * @return hfs_Response whose payload is an hfs_AlertsBadgeDTO on success; an error response
     *         (isSuccess=false) when the upstream alerts model is unavailable.
     */
    @AuraEnabled(cacheable=true)
    public static hfs_Response getUnreadAlertCount() {
        try {
            if (Test.isRunningTest() && forceFailure) {
                throw new System.QueryException('Forced failure for catch-branch coverage.');
            }
            hfs_AlertsService service = (hfs_AlertsService) hfs_Application.Service.newInstance(
                hfs_AlertsService.class
            );
            return hfs_Response.success(service.getUnreadAlertCount(UserInfo.getUserId()));
        } catch (Exception e) {
            return hfs_Response.error(e, FALLBACK_CODE, System.Label.hfs_Header_Alerts_Unavailable);
        }
    }
}