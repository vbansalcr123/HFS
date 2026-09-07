import { LightningElement, api } from 'lwc';

/**
 * Registration form section (child). Owns the input fields and their validity
 * reporting, but holds no business logic — it emits a `submit` event with the
 * entered field values and a `signin` event, letting the page container call
 * Apex and navigate. Busy/error state and all labels are passed down via @api.
 */
export default class Hfs_registrationForm extends LightningElement {
    @api isBusy = false;
    @api errorMessage = '';

    // Labels (supplied by the container so all text stays as Custom Labels).
    @api labelCompany;
    @api labelName;
    @api labelPhone;
    @api labelEmail;
    @api labelPartnerType;
    @api labelPartnerTypePlaceholder;
    @api labelTerritory;
    @api labelMessage;
    @api labelRegister;
    @api labelSignIn;
    @api labelRequired;
    @api cardTitle;
    @api cardSubtitle;

    // Partner-type picklist options (Dealer / Jobber-Distributor), supplied by
    // the container so the visible text stays as Custom Labels.
    @api partnerTypeOptions = [];

    company = '';
    name = '';
    phone = '';
    email = '';
    partnerType = '';
    territory = '';
    message = '';

    handleCompanyChange(event) {
        this.company = event.target.value;
    }

    handleNameChange(event) {
        this.name = event.target.value;
    }

    handlePhoneChange(event) {
        this.phone = event.target.value;
    }

    handleEmailChange(event) {
        this.email = event.target.value;
    }

    handlePartnerTypeChange(event) {
        this.partnerType = event.detail.value;
    }

    handleTerritoryChange(event) {
        this.territory = event.target.value;
    }

    handleMessageChange(event) {
        this.message = event.target.value;
    }

    /**
     * Reports validity on the inputs, then emits `submit` with the values so the
     * container performs the Apex call.
     */
    handleSubmit() {
        if (this.isBusy) {
            return;
        }
        if (!this.reportValidity()) {
            return;
        }
        this.dispatchEvent(
            new CustomEvent('submit', {
                detail: {
                    company: this.company,
                    name: this.name,
                    phone: this.phone,
                    email: this.email,
                    partnerType: this.partnerType,
                    territory: this.territory,
                    message: this.message
                }
            })
        );
    }

    handleSignIn() {
        this.dispatchEvent(new CustomEvent('signin'));
    }

    /**
     * @returns {boolean} true when every input is valid
     */
    @api
    reportValidity() {
        const inputs = [
            ...this.template.querySelectorAll('lightning-input'),
            ...this.template.querySelectorAll('lightning-combobox'),
            ...this.template.querySelectorAll('lightning-textarea')
        ];
        let allValid = true;
        inputs.forEach((input) => {
            if (!input.reportValidity()) {
                allValid = false;
            }
        });
        return allValid;
    }

    get hasError() {
        return !!this.errorMessage;
    }
}