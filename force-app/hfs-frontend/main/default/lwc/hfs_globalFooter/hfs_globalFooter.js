import { LightningElement, api } from 'lwc';
import { labels, DEFAULT_LEGAL_LINKS } from './utils';

/**
 * Persistent global footer for the Sinclair Brand Portal chrome.
 *
 * Rendered once into the `footer` region of the site's single theme layout, so
 * it appears identically on every existing and future page. Presentational and
 * driven by design properties so the link sets are configuration.
 *
 * Legal links always render (guest + authenticated), including "Do Not Sell My
 * Information" (BR 0.4). Sibling-portal links render only when supplied; until
 * the exact links are confirmed (open question) the footer ships legal links
 * only, and sibling links are added later as configuration.
 *
 * All links are keyboard-reachable, operable native anchors (WCAG 2.1 AA).
 */
export default class Hfs_globalFooter extends LightningElement {
    // Optional JSON array of { label, url } for legal links overriding defaults.
    @api legalLinksJson;

    // Optional JSON array of { label, url } for sibling-portal links.
    @api siblingLinksJson;

    labels = labels;

    get legalLinks() {
        const parsed = this._parse(this.legalLinksJson);
        if (parsed && parsed.length) {
            return parsed.map((it, i) => ({
                key: it.url || `legal-${i}`,
                label: it.label,
                url: it.url
            }));
        }
        return DEFAULT_LEGAL_LINKS;
    }

    get siblingLinks() {
        const parsed = this._parse(this.siblingLinksJson);
        if (parsed && parsed.length) {
            return parsed.map((it, i) => ({
                key: it.url || `sibling-${i}`,
                label: it.label,
                url: it.url
            }));
        }
        return [];
    }

    get hasSiblingLinks() {
        return this.siblingLinks.length > 0;
    }

    _parse(json) {
        if (!json) {
            return null;
        }
        try {
            const parsed = JSON.parse(json);
            return Array.isArray(parsed) ? parsed : null;
        } catch (e) {
            // Malformed JSON -> fall back to defaults / empty.
            return null;
        }
    }
}