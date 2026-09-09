import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import isGuest from '@salesforce/user/isGuest';
import SINCLAIR_LOGO from '@salesforce/contentAssetUrl/hfs_Sinclair_Logo';
import { labels, OPEN_TOOLBOX_EVENT } from './utils';

/**
 * Persistent global header for the Sinclair Brand Portal chrome.
 *
 * Rendered once into the `header` region of the site's single theme layout, so
 * it appears identically on every existing and future page. Element order is
 * brand identity -> primary navigation (hfs_globalNav) -> utilities (search,
 * language, alerts, account), per AC4.
 *
 * The eyebrow differs only by authentication state (a platform-native
 * distinction, not an audience rule):
 *   - Guest    : Login, Register.
 *   - Signed-in: Profile, Cart, My Toolbox, Alerts (hfs_alertsBadge).
 *
 * Utility controls are entry points only: search navigates to the portal search
 * route (results are BR 11), the My Toolbox link fires the site-wide
 * `opentoolbox` event, and account/cart navigate to their named pages. All
 * inter-route navigation uses comm__namedPage so the site UrlPathPrefix is
 * respected.
 */
export default class Hfs_globalHeader extends NavigationMixin(LightningElement) {
    // ContentAsset URL for the brand logo; defaults to the bundled Sinclair Dino
    // logo ContentAsset and falls back to the text lockup only if unset.
    @api logoAssetUrl = SINCLAIR_LOGO;

    // Named LWR route for the portal search entry point.
    @api searchRouteName = 'Search__c';

    // Named routes for the account/profile and cart entry points.
    @api profileRouteName = 'my-profile';
    @api cartRouteName = 'Cart__c';
    // Named route for the account "Settings" entry (post-publish route).
    @api settingsRouteName = 'my-settings';

    // Developer name of the NavigationLinkSet passed through to hfs_globalNav.
    @api navigationLinkSetDeveloperName = 'hfs_Dry_Run_Primary';

    labels = labels;
    searchTerm = '';
    _accountMenuOpen = false;
    _boundOutsideClick;

    get isGuest() {
        return isGuest;
    }

    get isSignedIn() {
        return !isGuest;
    }

    get hasLogo() {
        return !!this.logoAssetUrl;
    }

    get accountMenuOpen() {
        return this._accountMenuOpen;
    }

    get accountMenuExpanded() {
        return String(this._accountMenuOpen);
    }

    get accountMenuClass() {
        return this._accountMenuOpen
            ? 'hfs-header__account-menu hfs-header__account-menu--open'
            : 'hfs-header__account-menu';
    }

    disconnectedCallback() {
        this.removeOutsideClickListener();
    }

    handleAccountClick(event) {
        event.preventDefault();
        event.stopPropagation();
        this._accountMenuOpen = !this._accountMenuOpen;
        if (this._accountMenuOpen) {
            this.addOutsideClickListener();
        } else {
            this.removeOutsideClickListener();
        }
    }

    closeAccountMenu() {
        this._accountMenuOpen = false;
        this.removeOutsideClickListener();
    }

    addOutsideClickListener() {
        if (typeof document === 'undefined' || this._boundOutsideClick) {
            return;
        }
        this._boundOutsideClick = this.handleOutsideClick.bind(this);
        document.addEventListener('click', this._boundOutsideClick);
    }

    removeOutsideClickListener() {
        if (typeof document === 'undefined' || !this._boundOutsideClick) {
            return;
        }
        document.removeEventListener('click', this._boundOutsideClick);
        this._boundOutsideClick = undefined;
    }

    handleOutsideClick(event) {
        // Close when the click falls outside this header's account control.
        const account = this.template.querySelector('.hfs-header__account-wrap');
        if (account && !account.contains(event.target)) {
            this.closeAccountMenu();
        }
    }

    handleProfileSelect(event) {
        event.preventDefault();
        this.closeAccountMenu();
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: this.profileRouteName }
        });
    }

    handleToolboxSelect(event) {
        event.preventDefault();
        this.closeAccountMenu();
        this.dispatchEvent(
            new CustomEvent(OPEN_TOOLBOX_EVENT, { bubbles: true, composed: true })
        );
    }

    handleSettingsSelect(event) {
        event.preventDefault();
        this.closeAccountMenu();
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: this.settingsRouteName }
        });
    }

    handleLogoutSelect(event) {
        event.preventDefault();
        this.closeAccountMenu();
        // Standard Experience Cloud logout route.
        this[NavigationMixin.Navigate]({
            type: 'comm__loginPage',
            attributes: { actionName: 'logout' }
        });
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    handleSearchSubmit(event) {
        if (event && event.key && event.key !== 'Enter') {
            return;
        }
        // Entry point only - navigate to the search route; results are BR 11.
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: this.searchRouteName },
            state: this.searchTerm ? { term: this.searchTerm } : {}
        });
    }

    handleToolboxClick(event) {
        event.preventDefault();
        // Open the My Toolbox panel on the current page (HFS-27) without navigation.
        this.dispatchEvent(
            new CustomEvent(OPEN_TOOLBOX_EVENT, { bubbles: true, composed: true })
        );
    }

    handleCartClick(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: this.cartRouteName }
        });
    }

    handleLoginClick(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'Login' }
        });
    }

    handleRegisterClick(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'Register' }
        });
    }

    handleBrandClick(event) {
        event.preventDefault();
        // The brand logo/name must always return to the site home (landing
        // route). comm__namedPage name resolution for the landing route is
        // unreliable on this LWR site, so navigate to the site base URL
        // directly, which is deterministic regardless of route apiName.
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: this.homeUrl }
        });
    }

    get homeUrl() {
        // Derive the site base path (e.g. "/dryrun") from the current URL so
        // this works across the site domain without hard-coding it.
        if (typeof window === 'undefined' || !window.location) {
            return '/';
        }
        const path = window.location.pathname || '/';
        // Site pages live under "/<siteBase>/..."; the first segment is the base.
        const segments = path.split('/').filter((s) => s.length > 0);
        return segments.length > 0 ? `/${segments[0]}` : '/';
    }
}