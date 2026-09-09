import HOME from '@salesforce/label/c.hfs_Header_Menu_Toggle';

/**
 * Colocated constants for hfs_globalNav. The representative primary navigation
 * set (SD: Home, Brand Assets, Resources, Programs, Training, Reports, Help) is
 * supplied as configuration via a design property; this default is used only
 * when the property is empty, so the item set stays configuration - not
 * hard-coded logic - and a future change is a property edit, not a rebuild.
 *
 * Only the `home` route exists in the deployed bundle today; the other routes
 * are created by their own stories. Items therefore carry an explicit route
 * `name` and are wired to their pages post-publish (see design Dependencies).
 */
export const labels = {
    menuToggle: HOME
};

// name = LWR route apiName used with comm__namedPage; label = display text.
// routeName MUST be the exact site route apiName (case-sensitive for
// navigation): the landing route is `Home` (resolves to the site root), and
// the Training page is `Training_Module__c` (/training-module). urlName is the
// route's URL segment, used to determine the active item from the current URL
// (deterministic; the empty string means the site root / landing page).
// available = whether the target page exists in the deployed site today. Items
// flagged available:false render but are inert (no navigation to an invalid
// page) until their page ships - flip the flag (config edit) when it does.
export const DEFAULT_ITEMS = [
    { name: 'Home', label: 'Home', routeName: 'Home', urlName: '', available: true },
    { name: 'Brand_Assets__c', label: 'Brand Assets', routeName: 'Brand_Assets__c', urlName: 'brand-assets', available: false },
    { name: 'Resources__c', label: 'Resources', routeName: 'Resources__c', urlName: 'resources', available: false },
    { name: 'Programs__c', label: 'Programs', routeName: 'Programs__c', urlName: 'programs', available: false },
    { name: 'Training__c', label: 'Training', routeName: 'Training_Module__c', urlName: 'training-module', available: true },
    { name: 'Reports__c', label: 'Reports', routeName: 'Reports__c', urlName: 'reports', available: false },
    { name: 'Help__c', label: 'Help', routeName: 'Help__c', urlName: 'help', available: false }
];