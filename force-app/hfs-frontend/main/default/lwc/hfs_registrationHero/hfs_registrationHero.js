import { LightningElement, api } from 'lwc';

/**
 * Presentational (dumb) brand hero section for the registration page. Renders
 * only the copy passed down by the page container; holds no business logic.
 */
export default class Cr_hfs_registrationHero extends LightningElement {
    @api heroTitle;
    @api heroBody;
}