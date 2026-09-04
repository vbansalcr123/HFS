import TITLE from '@salesforce/label/c.hfs_Register_Title';
import SUBTITLE from '@salesforce/label/c.hfs_Register_Subtitle';
import HERO_TITLE from '@salesforce/label/c.hfs_Register_Hero_Title';
import HERO_BODY from '@salesforce/label/c.hfs_Register_Hero_Body';
import FIELD_COMPANY from '@salesforce/label/c.hfs_Field_Company';
import FIELD_NAME from '@salesforce/label/c.hfs_Field_Name';
import FIELD_PHONE from '@salesforce/label/c.hfs_Field_Phone';
import FIELD_EMAIL from '@salesforce/label/c.hfs_Field_Email';
import FIELD_PARTNER_TYPE from '@salesforce/label/c.hfs_Field_Partner_Type';
import FIELD_PARTNER_TYPE_PLACEHOLDER from '@salesforce/label/c.hfs_Field_Partner_Type_Placeholder';
import FIELD_TERRITORY from '@salesforce/label/c.hfs_Field_Territory';
import FIELD_MESSAGE from '@salesforce/label/c.hfs_Field_Message';
import PARTNER_TYPE_DEALER from '@salesforce/label/c.hfs_Partner_Type_Dealer';
import PARTNER_TYPE_DISTRIBUTOR from '@salesforce/label/c.hfs_Partner_Type_Distributor';
import BTN_REGISTER from '@salesforce/label/c.hfs_Button_Register';
import LINK_SIGN_IN from '@salesforce/label/c.hfs_Link_Sign_In';
import MSG_REQUIRED from '@salesforce/label/c.hfs_Msg_Required_Fields';
import MSG_INVALID_EMAIL from '@salesforce/label/c.hfs_Msg_Invalid_Email';
import MSG_CHECK_EMAIL from '@salesforce/label/c.hfs_Msg_Check_Email';

export const labels = {
    title: TITLE,
    subtitle: SUBTITLE,
    heroTitle: HERO_TITLE,
    heroBody: HERO_BODY,
    fieldCompany: FIELD_COMPANY,
    fieldName: FIELD_NAME,
    fieldPhone: FIELD_PHONE,
    fieldEmail: FIELD_EMAIL,
    fieldPartnerType: FIELD_PARTNER_TYPE,
    fieldPartnerTypePlaceholder: FIELD_PARTNER_TYPE_PLACEHOLDER,
    fieldTerritory: FIELD_TERRITORY,
    fieldMessage: FIELD_MESSAGE,
    btnRegister: BTN_REGISTER,
    linkSignIn: LINK_SIGN_IN,
    msgRequired: MSG_REQUIRED,
    msgInvalidEmail: MSG_INVALID_EMAIL,
    msgCheckEmail: MSG_CHECK_EMAIL
};

// Partner-type picklist options. Values are stable API-side tokens; labels are
// Custom Labels so the visible text is translatable / configurable.
export const partnerTypeOptions = [
    { label: PARTNER_TYPE_DEALER, value: 'Dealer' },
    { label: PARTNER_TYPE_DISTRIBUTOR, value: 'Distributor' }
];

export const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;