import { LightningElement, api } from 'lwc';

export default class ContactCard extends LightningElement {
    @api firstName;
    @api lastName;
    @api email;
    @api phone;

    get fullName() {
        return [this.firstName, this.lastName].filter(Boolean).join(' ');
    }
}
