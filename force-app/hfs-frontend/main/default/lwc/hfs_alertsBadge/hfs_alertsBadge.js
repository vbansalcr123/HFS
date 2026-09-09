import { LightningElement, wire } from 'lwc';
import getUnreadAlertCount from '@salesforce/apex/hfs_AlertsController.getUnreadAlertCount';
import {
    labels,
    STATE_LOADING,
    STATE_COUNT,
    STATE_UNAVAILABLE,
    formatUnread
} from './utils';

/**
 * Unread-alert count badge for the global-header eyebrow (signed-in users only).
 *
 * Renders three explicit states so it never shows a stale or zeroed value while
 * loading, and never shows another user's count:
 *   - LOADING     : the wire has not resolved yet (subtle skeleton dot).
 *   - COUNT       : a real, own-user count is available (red pill).
 *   - UNAVAILABLE : the Apex response is a business failure (dimmed dot, no number).
 *
 * It follows the project hfs_Response contract: because the controller is
 * cacheable and catches its own exceptions, a business failure resolves into the
 * wire's data branch, so the component checks data.isSuccess rather than relying
 * on the wire error branch.
 */
export default class Hfs_alertsBadge extends LightningElement {
    labels = labels;
    _state = STATE_LOADING;
    _count = 0;

    @wire(getUnreadAlertCount)
    wiredCount({ data, error }) {
        if (data) {
            if (data.isSuccess && data.payload && data.payload.status === STATE_COUNT) {
                this._count = data.payload.unreadCount;
                this._state = STATE_COUNT;
            } else {
                // Business failure (e.g. upstream HFS-41 model absent) -> unavailable.
                this._state = STATE_UNAVAILABLE;
            }
        } else if (error) {
            // Transport-level failure is also treated as unavailable, never zero.
            this._state = STATE_UNAVAILABLE;
        }
    }

    get isLoading() {
        return this._state === STATE_LOADING;
    }

    get isCount() {
        return this._state === STATE_COUNT;
    }

    get isUnavailable() {
        return this._state === STATE_UNAVAILABLE;
    }

    // Only show the numeric pill when there is at least one unread alert.
    get showCountPill() {
        return this.isCount && this._count > 0;
    }

    get count() {
        return this._count;
    }

    get ariaLabel() {
        if (this.isLoading) {
            return this.labels.loading;
        }
        if (this.isUnavailable) {
            return this.labels.unavailable;
        }
        return formatUnread(this.labels.unreadCountTemplate, this._count);
    }

    get isBusy() {
        return this.isLoading ? 'true' : 'false';
    }
}