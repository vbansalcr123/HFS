import HEADING from '@salesforce/label/c.hfs_Footer_Heading';
import LEGAL_HEADING from '@salesforce/label/c.hfs_Footer_Legal_Heading';
import SIBLING_HEADING from '@salesforce/label/c.hfs_Footer_Sibling_Heading';
import COPYRIGHT from '@salesforce/label/c.hfs_Footer_Copyright';
import LEGAL_PRIVACY from '@salesforce/label/c.hfs_Footer_Legal_Privacy';
import LEGAL_TERMS from '@salesforce/label/c.hfs_Footer_Legal_Terms';
import LEGAL_DO_NOT_SELL from '@salesforce/label/c.hfs_Footer_Legal_DoNotSell';

/**
 * Colocated Custom Labels and default link sets for hfs_globalFooter.
 */
export const labels = {
    heading: HEADING,
    legalHeading: LEGAL_HEADING,
    siblingHeading: SIBLING_HEADING,
    copyright: COPYRIGHT,
    legalPrivacy: LEGAL_PRIVACY,
    legalTerms: LEGAL_TERMS,
    legalDoNotSell: LEGAL_DO_NOT_SELL
};

// Legal links always render (guest + authenticated), including
// "Do Not Sell My Information" (BR 0.4). URLs are configuration; sensible
// site-relative defaults are used until the exact targets are supplied.
export const DEFAULT_LEGAL_LINKS = [
    { key: 'privacy', label: LEGAL_PRIVACY, url: '/privacy' },
    { key: 'terms', label: LEGAL_TERMS, url: '/terms' },
    { key: 'do-not-sell', label: LEGAL_DO_NOT_SELL, url: '/do-not-sell' }
];