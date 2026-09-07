import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

/**
 * Presentational, dismissible announcement banner. Renders title, message and a CTA link from
 * props; renders nothing when there is no announcement. Internal CTA targets are resolved via
 * NavigationMixin.GenerateUrl so they honour the site's URL prefix (never a root-relative href).
 */
export default class Hfs_announcementBanner extends NavigationMixin(LightningElement) {
    /** Banner headline. */
    @api title;
    /** Banner body copy. */
    @api message;
    /** CTA link text. */
    @api ctaLabel;

    _ctaUrl;
    resolvedUrl;
    dismissed = false;

    /** CTA target (site-relative / allow-listed). */
    @api
    get ctaUrl() {
        return this._ctaUrl;
    }
    set ctaUrl(value) {
        this._ctaUrl = value;
        this.resolveUrl(value);
    }

    get showBanner() {
        return !this.dismissed && !!this.title;
    }

    get showCta() {
        return !!this.ctaLabel && !!this.resolvedUrl;
    }

    resolveUrl(value) {
        if (!value) {
            this.resolvedUrl = undefined;
            return;
        }
        // External absolute URL: use as-is. Site-relative path: resolve to a standard web page.
        if (/^https?:\/\//i.test(value)) {
            this.resolvedUrl = value;
            return;
        }
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__webPage',
            attributes: { url: value }
        })
            .then((url) => {
                this.resolvedUrl = url;
            })
            .catch(() => {
                this.resolvedUrl = undefined;
            });
    }

    handleDismiss() {
        this.dismissed = true;
    }
}