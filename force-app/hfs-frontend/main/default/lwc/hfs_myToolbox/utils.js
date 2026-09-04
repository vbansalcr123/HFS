import PANEL_TITLE from '@salesforce/label/c.hfs_Toolbox_Panel_Title';
import GROUP_QUICK_ACTIONS from '@salesforce/label/c.hfs_Toolbox_Group_Quick_Actions';
import GROUP_MY_PROGRAMS from '@salesforce/label/c.hfs_Toolbox_Group_My_Programs';
import GROUP_ACCOUNT from '@salesforce/label/c.hfs_Toolbox_Group_Account';
import PROGRAMS_EMPTY from '@salesforce/label/c.hfs_Toolbox_Programs_Empty';
import LOADING from '@salesforce/label/c.hfs_Toolbox_Loading';
import CLOSE from '@salesforce/label/c.hfs_Toolbox_Close';
import COLLAPSE from '@salesforce/label/c.hfs_Toolbox_Collapse';
import EXPAND from '@salesforce/label/c.hfs_Toolbox_Expand';

export const labels = {
    panelTitle: PANEL_TITLE,
    groupQuickActions: GROUP_QUICK_ACTIONS,
    groupMyPrograms: GROUP_MY_PROGRAMS,
    groupAccount: GROUP_ACCOUNT,
    programsEmpty: PROGRAMS_EMPTY,
    loading: LOADING,
    close: CLOSE,
    collapsePanel: COLLAPSE,
    expandPanel: EXPAND
};

// Status tokens shared with the Apex DTO layer.
export const STATUS_AVAILABLE = 'AVAILABLE';
export const STATUS_UNAVAILABLE = 'UNAVAILABLE';

// Site-wide event dispatched by the eyebrow link and the Home tile.
export const OPEN_TOOLBOX_EVENT = 'opentoolbox';