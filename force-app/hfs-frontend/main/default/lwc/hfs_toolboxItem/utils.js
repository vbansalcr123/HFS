import ITEMS_SUFFIX from '@salesforce/label/c.hfs_Toolbox_Items_Suffix';
import UNAVAILABLE from '@salesforce/label/c.hfs_Toolbox_Unavailable';

export const labels = {
    itemsSuffix: ITEMS_SUFFIX,
    unavailable: UNAVAILABLE
};

// Status tokens shared with the Apex DTO layer.
export const STATUS_AVAILABLE = 'AVAILABLE';
export const STATUS_UNAVAILABLE = 'UNAVAILABLE';