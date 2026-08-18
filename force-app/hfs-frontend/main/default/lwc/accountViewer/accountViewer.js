import { LightningElement, api } from 'lwc';

export default class AccountViewer extends LightningElement {
    @api accountName;
    unusedVariable = 42;

    renderedCallback() {
        const container = this.template.querySelector('.account-name');
        if (container) {
            container.innerHTML = this.accountName;
        }
    }
}
