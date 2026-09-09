/**
 * @description DTO returned to the hfs_alertsBadge LWC as the payload of an
 * hfs_Response. Carries the running user's own unread alert count plus a status
 * token so the badge can render its loading / count / unavailable states without
 * a raw SObject ever crossing the Controller boundary.
 */
public class hfs_AlertsBadgeDTO {
    /** Status token: a real count is available. */
    public static final String STATUS_COUNT = 'COUNT';

    /** Status token: the upstream alerts model is absent, so no count can be shown. */
    public static final String STATUS_UNAVAILABLE = 'UNAVAILABLE';

    /** COUNT when a real count is available; UNAVAILABLE when the upstream alerts model is absent. */
    @AuraEnabled
    public String status { get; set; }

    /** The running user's own unread-alert count (0 or more). Meaningful only when status == COUNT. */
    @AuraEnabled
    public Integer unreadCount { get; set; }

    /**
     * @description Convenience constructor.
     * @param status the badge status token (COUNT / UNAVAILABLE)
     * @param unreadCount the running user's unread count
     */
    public hfs_AlertsBadgeDTO(String status, Integer unreadCount) {
        this.status = status;
        this.unreadCount = unreadCount;
    }
}