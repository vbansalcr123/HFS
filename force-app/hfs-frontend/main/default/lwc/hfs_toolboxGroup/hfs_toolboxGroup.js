import { LightningElement, api } from 'lwc';
import { labels as groupLabels, STATUS_UNAVAILABLE } from './utils';

/**
 * Presentational My Toolbox group: renders a group heading and iterates
 * hfs_toolboxItem rows. Shows an empty-state message or an "unavailable"
 * message when appropriate. Dumb component — no Apex.
 */
export default class Hfs_toolboxGroup extends LightningElement {
    @api label;
    @api items = [];
    @api emptyMessage;
    @api status;

    labels = groupLabels;

    get isUnavailable() {
        return this.status === STATUS_UNAVAILABLE;
    }

    get hasItems() {
        return Array.isArray(this.items) && this.items.length > 0;
    }

    get showEmpty() {
        return !this.isUnavailable && !this.hasItems;
    }

    get unavailableText() {
        return groupLabels.unavailable;
    }

    get headingId() {
        return `hfs-group-${(this.label || '').replace(/\s+/g, '-').toLowerCase()}`;
    }

    handleItemSelect(event) {
        // Re-dispatch selection up to the container.
        this.dispatchEvent(
            new CustomEvent('itemselect', { detail: event.detail })
        );
    }
}