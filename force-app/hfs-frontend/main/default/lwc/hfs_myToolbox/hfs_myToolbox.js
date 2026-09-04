import { LightningElement, api, wire, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getQuickActions from "@salesforce/apex/hfs_ToolboxController.getQuickActions";
import getMyPrograms from "@salesforce/apex/hfs_ToolboxController.getMyPrograms";
import getAccountLinks from "@salesforce/apex/hfs_ToolboxController.getAccountLinks";
import { labels as toolboxLabels, STATUS_UNAVAILABLE } from "./utils";

/**
 * Smart container for the persistent My Toolbox sidebar. Renders as an
 * always-visible vertical panel (drop once in a global/theme region so it
 * appears on every page). Owns data fetching via three Apex controllers and
 * per-group loading/error state, and navigates on item selection. Renders the
 * three groups strictly in order: Quick Actions, My Programs, Account.
 */
export default class Hfs_myToolbox extends NavigationMixin(LightningElement) {
  @api panelTitle;

  labels = toolboxLabels;

  // Collapsed (icon-rail) vs expanded (full) state of the sidebar.
  @track isCollapsed = false;

  // Quick Actions group state.
  @track quickActions = [];
  quickActionsLoading = true;
  quickActionsStatus;

  // My Programs group state.
  @track programs = [];
  programsLoading = true;
  programsStatus;

  // Account group state.
  @track accountLinks = [];
  accountLoading = true;
  accountStatus;

  @wire(getQuickActions)
  wiredQuickActions({ data, error }) {
    this.quickActionsLoading = false;
    if (data && data.isSuccess) {
      this.quickActions = data.payload;
      this.quickActionsStatus = undefined;
    } else {
      this.quickActions = [];
      this.quickActionsStatus = STATUS_UNAVAILABLE;
    }
    if (error) {
      this.quickActionsStatus = STATUS_UNAVAILABLE;
    }
  }

  @wire(getMyPrograms)
  wiredPrograms({ data, error }) {
    this.programsLoading = false;
    if (data && data.isSuccess) {
      this.programs = data.payload.programs || [];
      this.programsStatus = data.payload.listStatus;
    } else {
      this.programs = [];
      this.programsStatus = STATUS_UNAVAILABLE;
    }
    if (error) {
      this.programsStatus = STATUS_UNAVAILABLE;
    }
  }

  @wire(getAccountLinks)
  wiredAccountLinks({ data, error }) {
    this.accountLoading = false;
    if (data && data.isSuccess) {
      this.accountLinks = data.payload;
      this.accountStatus = undefined;
    } else {
      this.accountLinks = [];
      this.accountStatus = STATUS_UNAVAILABLE;
    }
    if (error) {
      this.accountStatus = STATUS_UNAVAILABLE;
    }
  }

  get resolvedTitle() {
    return this.panelTitle || toolboxLabels.panelTitle;
  }

  get quickActionsLabel() {
    return toolboxLabels.groupQuickActions;
  }

  get myProgramsLabel() {
    return toolboxLabels.groupMyPrograms;
  }

  get accountLabel() {
    return toolboxLabels.groupAccount;
  }

  get programsEmptyMessage() {
    return toolboxLabels.programsEmpty;
  }

  get sectionClass() {
    return this.isCollapsed
      ? "hfs-toolbox hfs-toolbox--collapsed"
      : "hfs-toolbox";
  }

  get isExpanded() {
    return !this.isCollapsed;
  }

  get ariaExpanded() {
    return String(!this.isCollapsed);
  }

  get toggleLabel() {
    return this.isCollapsed
      ? toolboxLabels.expandPanel
      : toolboxLabels.collapsePanel;
  }

  get toggleIcon() {
    return this.isCollapsed ? "utility:chevronright" : "utility:chevronleft";
  }

  handleToggle() {
    this.isCollapsed = !this.isCollapsed;
  }

  handleItemSelect() {
    // Story scope: destination pages for the individual items are delivered
    // by a later story. Until then every item redirects to an external
    // placeholder. Replace this with per-item `event.detail.destination`
    // navigation when those pages exist.
    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: { url: "https://www.google.com" }
    });
  }
}
