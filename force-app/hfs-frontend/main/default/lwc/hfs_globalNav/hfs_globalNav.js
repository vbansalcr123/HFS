import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { labels, DEFAULT_ITEMS } from './utils';

/**
 * Global primary navigation for the Sinclair Brand Portal chrome.
 *
 * Renders the site's primary menu items and marks the active section. Items are
 * configuration: they come from the `menuItemsJson` design property (a JSON
 * array of { label, routeName }) and fall back to the representative primary set
 * when the property is empty. A future change is a property edit, never a
 * rebuild.
 *
 * All inter-route links use NavigationMixin.GenerateUrl with comm__namedPage so
 * the site UrlPathPrefix is respected (never root-relative hrefs). The active
 * section is announced via aria-current in addition to the red visual indicator,
 * so state is not conveyed by colour alone (WCAG 2.1 AA). Below 768px the menu
 * collapses behind a toggle button.
 *
 * Per the confirmed scope, no audience targeting is applied in this release: the
 * same menu renders for every user. Audience rules are the documented future
 * extensibility path and require no change here.
 */
export default class Hfs_globalNav extends NavigationMixin(LightningElement) {
    // The NavigationLinkSet developer name (reserved for future audience-driven
    // NavigationMenu rendering); retained so wiring a menu later needs no rebuild.
    @api navigationLinkSetDeveloperName;

    // Optional JSON array of { label, routeName } overriding the default items.
    @api menuItemsJson;

    labels = labels;
    _mobileOpen = false;
    _currentSegment = '';

    @wire(CurrentPageReference)
    setCurrentPage(pageRef) {
        // Derive the active section from the URL path, which is unambiguous on
        // an LWR site (comm__namedPage attribute casing is unreliable). The
        // CurrentPageReference wire re-fires on client-side route changes, so
        // reading location here keeps the active item in sync during SPA nav.
        if (pageRef) {
            this._currentSegment = this.currentUrlSegment();
        }
    }

    connectedCallback() {
        this._currentSegment = this.currentUrlSegment();
    }

    /**
     * Last meaningful segment of the current URL path, lowercased. The site is
     * served under a URL prefix (e.g. /dryrun); the landing page has no extra
     * segment beyond the prefix, so it resolves to '' (matching Home's urlName).
     */
    currentUrlSegment() {
        if (typeof window === 'undefined' || !window.location) {
            return '';
        }
        const parts = window.location.pathname
            .split('/')
            .filter((p) => p && p.length);
        if (!parts.length) {
            return '';
        }
        const last = parts[parts.length - 1].toLowerCase();
        // Known site URL-prefix / landing tokens map to the home landing page.
        if (last === 'dryrun' || last === 's' || last === 'home') {
            return '';
        }
        return last;
    }

    get rawItems() {
        if (this.menuItemsJson) {
            try {
                const parsed = JSON.parse(this.menuItemsJson);
                if (Array.isArray(parsed) && parsed.length) {
                    return parsed.map((it) => ({
                        name: it.routeName || it.name,
                        label: it.label,
                        routeName: it.routeName || it.name,
                        urlName: (it.urlName || '').toLowerCase(),
                        available: it.available !== false
                    }));
                }
            } catch {
                // Malformed JSON -> fall back to the default representative set.
            }
        }
        return DEFAULT_ITEMS;
    }

    get computedItems() {
        const current = this._currentSegment || '';
        return this.rawItems.map((item) => {
            const available = item.available !== false;
            const routeName = item.routeName || item.name;
            const urlName = (item.urlName || '').toLowerCase();
            const isActive = available && urlName === current;
            let cssClass = 'hfs-nav__link';
            if (isActive) {
                cssClass += ' hfs-nav__link--active';
            }
            if (!available) {
                cssClass += ' hfs-nav__link--disabled';
            }
            return {
                key: routeName,
                label: item.label,
                isActive,
                available,
                ariaCurrent: isActive ? 'page' : null,
                ariaDisabled: available ? null : 'true',
                cssClass,
                pageRef: {
                    type: 'comm__namedPage',
                    attributes: { name: routeName }
                }
            };
        });
    }

    get navListClass() {
        return this._mobileOpen
            ? 'hfs-nav__list hfs-nav__list--open'
            : 'hfs-nav__list';
    }

    get mobileExpanded() {
        return String(this._mobileOpen);
    }

    toggleMobileMenu() {
        this._mobileOpen = !this._mobileOpen;
    }

    handleItemClick(event) {
        event.preventDefault();
        const routeName = event.currentTarget.dataset.route;
        const item = this.rawItems.find(
            (it) => (it.routeName || it.name) === routeName
        );
        // Only navigate to pages that exist today; an unavailable item is inert
        // so clicking it never lands the user on an invalid/error page.
        if (item && item.available === false) {
            return;
        }
        this._mobileOpen = false;
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: routeName }
        });
    }
}