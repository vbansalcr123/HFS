import { LightningElement, api, wire } from 'lwc';
import getHighRiskOpportunities from '@salesforce/apex/OpportunityRiskController.getHighRiskOpportunities';

export default class OpportunityRiskList extends LightningElement {
    @api accountId;
    opportunities = [];
    error;

    @wire(getHighRiskOpportunities, { accountIds: '$wiredAccountIds' })
    wiredOpportunities({ data, error }) {
        if (data) {
            this.opportunities = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.opportunities = [];
        }
    }

    get wiredAccountIds() {
        return this.accountId ? [this.accountId] : [];
    }

    get hasOpportunities() {
        return this.opportunities.length > 0;
    }
}
