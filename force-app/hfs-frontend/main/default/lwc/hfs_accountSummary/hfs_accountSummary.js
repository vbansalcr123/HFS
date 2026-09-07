import { LightningElement, api } from 'lwc';
import { labels } from './utils';

/**
 * Presentational greeting + account-summary line. Renders the personalised greeting and the
 * account line ({name} · {address} · Account #{number} · Tier: {tier}) from props. Dumb component.
 */
export default class Hfs_accountSummary extends LightningElement {
    /** First name for the greeting. */
    @api greetingName;
    /** Station / company name. */
    @api accountName;
    /** Formatted address line. */
    @api addressLine;
    /** Account number. */
    @api accountNumber;
    /** Partner tier. */
    @api tier;

    labels = labels;

    get greetingText() {
        const name = this.greetingName ? ` ${this.greetingName}` : '';
        return `${labels.greeting}${name} 👋`;
    }

    get summaryParts() {
        const parts = [];
        if (this.accountName) {
            parts.push({ key: 'name', text: this.accountName });
        }
        if (this.addressLine) {
            parts.push({ key: 'address', text: this.addressLine });
        }
        if (this.accountNumber) {
            parts.push({
                key: 'number',
                text: `${labels.accountNumberPrefix}${this.accountNumber}`
            });
        }
        if (this.tier) {
            parts.push({ key: 'tier', text: `${labels.tierPrefix} ${this.tier}` });
        }
        return parts;
    }
}