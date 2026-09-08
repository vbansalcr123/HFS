import BRAND_NAME from '@salesforce/label/c.hfs_Header_Brand_Name';
import BRAND_TAGLINE from '@salesforce/label/c.hfs_Header_Brand_Tagline';
import BRAND_LOGO_ALT from '@salesforce/label/c.hfs_Header_Brand_Logo_Alt';
import SEARCH_PLACEHOLDER from '@salesforce/label/c.hfs_Header_Search_Placeholder';
import SEARCH_LABEL from '@salesforce/label/c.hfs_Header_Search_Label';
import LANGUAGE_LABEL from '@salesforce/label/c.hfs_Header_Language_Label';
import LANGUAGE_ARIA from '@salesforce/label/c.hfs_Header_Language_Aria';
import LOGIN from '@salesforce/label/c.hfs_Header_Login';
import REGISTER from '@salesforce/label/c.hfs_Header_Register';
import PROFILE from '@salesforce/label/c.hfs_Header_Profile';
import CART from '@salesforce/label/c.hfs_Header_Cart';
import MY_TOOLBOX from '@salesforce/label/c.hfs_Header_My_Toolbox';
import ACCOUNT from '@salesforce/label/c.hfs_Header_Account';
import LOGOUT from '@salesforce/label/c.hfs_Header_Logout';
import SETTINGS from '@salesforce/label/c.hfs_Header_Settings';

/**
 * Colocated Custom Labels for hfs_globalHeader. The main .js imports from here
 * rather than importing labels directly (project convention).
 */
export const labels = {
    brandName: BRAND_NAME,
    brandTagline: BRAND_TAGLINE,
    brandLogoAlt: BRAND_LOGO_ALT,
    searchPlaceholder: SEARCH_PLACEHOLDER,
    searchLabel: SEARCH_LABEL,
    languageLabel: LANGUAGE_LABEL,
    languageAria: LANGUAGE_ARIA,
    login: LOGIN,
    register: REGISTER,
    profile: PROFILE,
    cart: CART,
    myToolbox: MY_TOOLBOX,
    account: ACCOUNT,
    myProfile: PROFILE,
    accountMenu: ACCOUNT,
    logout: LOGOUT,
    settings: SETTINGS
};

// Site-wide event fired when the eyebrow "My Toolbox" link is selected, so the
// My Toolbox panel (HFS-27) can open on the current page without navigation.
export const OPEN_TOOLBOX_EVENT = 'opentoolbox';