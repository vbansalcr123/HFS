import { LightningElement, wire } from 'lwc';
import getHomeDashboard from '@salesforce/apex/hfs_HomeDashboardController.getHomeDashboard';
import { ICON_BY_KEY } from './utils';

/**
 * Smart container for the personalised Home dashboard (HFS-32). Fetches the aggregated payload via
 * @wire and composes, in order: the announcement banner (when active), the greeting + account
 * summary, and the four summary tiles. Every Apex call returns hfs_Response, so the component
 * checks payload.isSuccess before touching the payload rather than relying on the wire error
 * branch. Read-only - the dashboard writes nothing back.
 */
export default class Hfs_homeDashboard extends LightningElement {
    dashboard;
    loading = true;
    hasError = false;

    @wire(getHomeDashboard)
    wiredDashboard({ error, data }) {
        this.loading = false;
        if (data) {
            if (data.isSuccess) {
                this.dashboard = data.payload;
                this.hasError = false;
            } else {
                // Business failure resolves into the data branch - check isSuccess, not error.
                this.dashboard = undefined;
                this.hasError = true;
            }
        } else if (error) {
            this.dashboard = undefined;
            this.hasError = true;
        }
    }

    get showBanner() {
        return !!(this.dashboard && this.dashboard.announcement);
    }

    get announcement() {
        return this.dashboard ? this.dashboard.announcement : undefined;
    }

    get accountSummary() {
        return this.dashboard ? this.dashboard.accountSummary : undefined;
    }

    get tiles() {
        const tiles = this.dashboard && this.dashboard.tiles ? this.dashboard.tiles : [];
        return tiles.map((tile) => ({
            ...tile,
            icon: ICON_BY_KEY[tile.key] || 'utility:info'
        }));
    }
}