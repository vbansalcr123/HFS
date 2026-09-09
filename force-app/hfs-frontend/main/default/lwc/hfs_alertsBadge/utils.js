import ALERTS from '@salesforce/label/c.hfs_Header_Alerts';
import ALERTS_LOADING from '@salesforce/label/c.hfs_Alerts_Loading';
import ALERTS_UNAVAILABLE from '@salesforce/label/c.hfs_Alerts_Unavailable_Short';
import ALERTS_UNREAD_COUNT from '@salesforce/label/c.hfs_Alerts_Unread_Count';

/**
 * Colocated Custom Labels and local constants for hfs_alertsBadge. The main .js
 * imports from here rather than importing labels directly (project convention).
 */
export const labels = {
    alerts: ALERTS,
    loading: ALERTS_LOADING,
    unavailable: ALERTS_UNAVAILABLE,
    unreadCountTemplate: ALERTS_UNREAD_COUNT
};

// Badge render states. LOADING while the wire is undefined; COUNT when the Apex
// response is a success; UNAVAILABLE when the response is a business failure
// (e.g. the upstream HFS-41 alerts model is not yet present). Never shows 0 as
// a stale/unavailable value.
export const STATE_LOADING = 'LOADING';
export const STATE_COUNT = 'COUNT';
export const STATE_UNAVAILABLE = 'UNAVAILABLE';

/**
 * Substitute {0} in the unread-count aria template with the count.
 * @param {string} template label template
 * @param {number} count unread count
 * @returns {string} formatted string
 */
export function formatUnread(template, count) {
    return (template || '').replace('{0}', String(count));
}