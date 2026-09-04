import { LightningElement, api } from 'lwc';
import { labels as itemLabels, STATUS_AVAILABLE, STATUS_UNAVAILABLE } from './utils';

/**
 * Presentational, selectable My Toolbox row: icon + label + optional count pill
 * or "unavailable" badge. Emits a `select` event carrying the destination.
 * Dumb component — no Apex, no navigation logic of its own.
 */
export default class Hfs_toolboxItem extends LightningElement {
    @api label;
    @api icon;
    @api destination;
    @api count;
    @api hasCount = false;
    @api countStatus = STATUS_AVAILABLE;

    labels = itemLabels;

    get showCount() {
        return this.hasCount && this.countStatus === STATUS_AVAILABLE;
    }

    get showUnavailable() {
        return this.hasCount && this.countStatus === STATUS_UNAVAILABLE;
    }

    get accessibleLabel() {
        if (this.showCount) {
            const suffix = itemLabels.itemsSuffix.replace('{0}', this.count);
            return `${this.label}, ${suffix}`;
        }
        if (this.showUnavailable) {
            return `${this.label}, ${itemLabels.unavailable}`;
        }
        return this.label;
    }

    get unavailableText() {
        return itemLabels.unavailable;
    }

    handleSelect() {
        this.dispatchEvent(
            new CustomEvent('select', {
                detail: { destination: this.destination, label: this.label }
            })
        );
    }

    handleKeyup(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleSelect();
        }
    }
}