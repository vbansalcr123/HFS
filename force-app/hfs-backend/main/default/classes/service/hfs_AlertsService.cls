/**
 * @description Service interface for the global-header alerts badge. Represents the single
 * read use case the header needs: the running user's own unread-alert count. Every Service is
 * an interface plus an implementation, resolved through hfs_Application so it can be mocked in
 * tests. Services throw typed exceptions and never construct an hfs_Response (a Controller
 * boundary concept).
 */
public interface hfs_AlertsService {
    /**
     * @description Use case: the running user's own unread-alert count for the header badge.
     * Degrades by throwing when the upstream alerts data model (HFS-41) is not yet present, so
     * the Controller can translate to an UNAVAILABLE badge state.
     * @param userId the running user's Id
     * @return an hfs_AlertsBadgeDTO carrying the count and a status token
     */
    hfs_AlertsBadgeDTO getUnreadAlertCount(Id userId);
}