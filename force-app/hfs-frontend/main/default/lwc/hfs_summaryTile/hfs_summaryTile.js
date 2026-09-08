import { LightningElement, api } from 'lwc';
import { labels, STATUS } from './utils';

/**
 * Presentational summary tile for the Home dashboard. Renders a label, value, supporting detail,
 * an optional progress bar, and the loading / empty / unavailable states. Dumb component - all
 * values are supplied by the smart container hfs_homeDashboard.
 */
export default class Hfs_summaryTile extends LightningElement {
    /** Tile label (e.g. "Active Orders"). */
    @api label;
    /** Current value string (e.g. "3" or "9 / 15 courses"). */
    @api value;
    /** Supporting detail line. */
    @api supportingDetail;
    /** OK / EMPTY / UNAVAILABLE. */
    @api status;
    /** Optional progress bar percent (Training Progress only). */
    @api progressPercent;
    /** Top-border accent colour. */
    @api accent;
    /** When true, the tile shows its loading skeleton instead of a value. */
    @api loading = false;

    labels = labels;

    get isUnavailable() {
        return this.status === STATUS.UNAVAILABLE;
    }

    get showValue() {
        return !this.loading && !this.isUnavailable;
    }

    get showProgress() {
        return this.showValue && this.progressPercent !== undefined && this.progressPercent !== null;
    }

    get accentStyle() {
        return `border-top: 4px solid ${this.accent || '#DEE1E6'};`;
    }

    get progressStyle() {
        const pct = Math.max(0, Math.min(100, Number(this.progressPercent) || 0));
        return `width: ${pct}%;`;
    }

    get progressLabel() {
        return `${this.label}: ${this.progressPercent}%`;
    }
}