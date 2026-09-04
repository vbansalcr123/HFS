import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import register from '@salesforce/apex/hfs_RegistrationController.register';
import { labels, partnerTypeOptions, EMAIL_REGEX } from './utils';
import { parseResponse, reduceError } from 'c/hfs_errorUtils';

/**
 * Page container for the public self-registration page. Composes the brand hero
 * and registration-form child sections, owns page state (busy / error), calls
 * the Apex Controller, and navigates on success. Child sections are dumb — they
 * render props and raise events. All business logic lives in Apex; the container
 * checks data.isSuccess on every response.
 */
export default class Hfs_selfRegistration extends NavigationMixin(LightningElement) {
    @api confirmationPageApiName = 'CheckEmail';
    @api loginPageApiName = 'Login';

    labels = labels;
    partnerTypeOptions = partnerTypeOptions;

    @track isBusy = false;
    @track errorMessage = '';

    /**
     * Handles the `submit` event from the form section: validate, guard against
     * double-submit, call Apex, then navigate to the confirmation page.
     * @param {CustomEvent} event detail = { company, name, phone, email,
     *   partnerType, territory, message }
     */
    async handleSubmit(event) {
        this.errorMessage = '';
        if (this.isBusy) {
            return;
        }
        const { company, name, phone, email, partnerType, territory, message } = event.detail;
        if (!company || !name || !partnerType || !EMAIL_REGEX.test(email)) {
            this.errorMessage = this.labels.msgInvalidEmail;
            return;
        }

        this.isBusy = true;
        try {
            const dto = { company, name, phone, email, partnerType, territory, message };
            const response = await register({ dto });
            const result = parseResponse(response);
            if (result.ok) {
                this.navigateToConfirmation(email);
            } else {
                this.errorMessage = result.message;
            }
        } catch (error) {
            this.errorMessage = reduceError(error);
        } finally {
            this.isBusy = false;
        }
    }

    navigateToConfirmation(email) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: this.confirmationPageApiName },
            state: { email }
        });
    }

    handleSignIn() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: this.loginPageApiName }
        });
    }
}