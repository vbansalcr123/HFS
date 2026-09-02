import { LightningElement, api } from "lwc";

/**
 * hfs_card
 *
 * Reusable, purely presentational asset card used across the Sinclair Brand
 * Portal (Brand Assets, Home suggested-content, Training, My Toolbox).
 *
 * The card holds NO Apex, NO data fetching and NO business logic. Content and
 * action configuration are supplied by the parent via three `@api` properties
 * and slots; the card renders them and emits events (download, addtocart,
 * favouritetoggle, open) that a smart container component handles.
 *
 * Public API (kept intentionally small — three inputs):
 *  - `assetInfo` : the full per-record payload (content + record-level state).
 *  - `actions`   : static button configuration (labels / disabled / visibility).
 *  - `selected`  : genuinely-interactive state — flips per click, independent
 *                  of the record data, so it stays a standalone reactive prop.
 *
 * Reproduces both mockup variants:
 *  - `list`  → compact text-link footer ("? Favourite" / "? Download")
 *  - `grid`  → solid red Download button + outlined Cart button, favourite star on media
 */
export default class Hfs_card extends LightningElement {
  /**
   * Full record payload. Shape:
   * {
   *   title, imageUrl, imageAlt,
   *   recordId, assetKey, layout, isNew, isFavourite,
   *   categoryPills: [{ text, colour }],
   *   metaLines: [{ text, warning? }]
   * }
   *
   * `categoryPills` is a parent-driven list — the card renders each pill's
   * `text` with a CSS class derived from `colour`. The card owns NO
   * category-to-colour business mapping.
   */
  _assetInfo = {};
  @api
  get assetInfo() {
    return this._assetInfo;
  }
  set assetInfo(value) {
    this._assetInfo = value && typeof value === "object" ? value : {};
  }

  /**
   * Static button config. Shape:
   * {
   *   downloadLabel, downloadDisabled, showDownload,
   *   cartLabel, cartDisabled, showCart,
   *   showFavourite, showFavouriteOnMedia
   * }
   * Missing show-* flags default to visible.
   */
  _actions = {};
  @api
  get actions() {
    return this._actions;
  }
  set actions(value) {
    this._actions = value && typeof value === "object" ? value : {};
  }

  /** Genuinely interactive — flips per click, independent of the record data. */
  @api selected = false;

  /** Supported pill colour tokens (map to `hfs-pill-<token>` CSS classes). */
  static PILL_COLOURS = [
    "blue",
    "green",
    "amber",
    "purple",
    "red",
    "slate",
    "neutral"
  ];

  // --- assetInfo accessors ------------------------------------------------
  get title() {
    return this._assetInfo.title;
  }

  get imageUrl() {
    return this._assetInfo.imageUrl;
  }

  get isNew() {
    return !!this._assetInfo.isNew;
  }

  get isFavourite() {
    return !!this._assetInfo.isFavourite;
  }

  get layout() {
    return this._assetInfo.layout || "grid";
  }

  // --- actions accessors (show-* default true) ----------------------------
  get downloadLabel() {
    return this._actions.downloadLabel || "Download";
  }

  get downloadDisabled() {
    return !!this._actions.downloadDisabled;
  }

  get cartLabel() {
    return this._actions.cartLabel || "Cart";
  }

  get cartDisabled() {
    return !!this._actions.cartDisabled;
  }

  get showDownload() {
    return this._actions.showDownload === undefined
      ? true
      : !!this._actions.showDownload;
  }

  get showCart() {
    return this._actions.showCart === undefined
      ? true
      : !!this._actions.showCart;
  }

  get showFavourite() {
    return this._actions.showFavourite === undefined
      ? true
      : !!this._actions.showFavourite;
  }

  get showFavouriteOnMedia() {
    return this._actions.showFavouriteOnMedia === undefined
      ? true
      : !!this._actions.showFavouriteOnMedia;
  }

  // --- Derived getters ----------------------------------------------------
  get isGrid() {
    return this.layout !== "list";
  }

  get isList() {
    return this.layout === "list";
  }

  get computedAlt() {
    return this._assetInfo.imageAlt || this.title || "";
  }

  get hasImage() {
    return !!this.imageUrl;
  }

  /**
   * Parent-driven pill list. Each entry maps to a rendered pill; the CSS
   * class is derived from `colour` (falling back to `neutral` when the
   * token is missing or unrecognised). No business category mapping here.
   */
  get categoryPills() {
    const pills = Array.isArray(this._assetInfo.categoryPills)
      ? this._assetInfo.categoryPills
      : [];
    return pills
      .filter((pill) => pill && pill.text)
      .map((pill, index) => {
        const colour = Hfs_card.PILL_COLOURS.includes(pill.colour)
          ? pill.colour
          : "neutral";
        return {
          key: `pill-${index}`,
          text: pill.text,
          cssClass: `hfs-category-pill hfs-cat-${colour}`
        };
      });
  }

  get hasCategoryPills() {
    return this.categoryPills.length > 0;
  }

  get cardClass() {
    return `hfs-card hfs-layout-${this.isGrid ? "grid" : "list"}${
      this.selected ? " hfs-selected" : ""
    }`;
  }

  /** Meta lines decorated with a stable key and a css class for warnings. */
  get decoratedMetaLines() {
    const lines = Array.isArray(this._assetInfo.metaLines)
      ? this._assetInfo.metaLines
      : [];
    return lines.map((line, index) => {
      const isWarning = !!(line && line.warning);
      return {
        key: `meta-${index}`,
        text: line && line.text ? line.text : "",
        warning: isWarning,
        cssClass: isWarning ? "hfs-meta-line hfs-meta-warning" : "hfs-meta-line"
      };
    });
  }

  get showFavouriteStar() {
    return this.showFavourite && this.isGrid && this.showFavouriteOnMedia;
  }

  get showFavouriteLink() {
    return this.showFavourite && this.isList;
  }

  get favouritePressed() {
    return this.isFavourite ? "true" : "false";
  }

  get favouriteLabel() {
    return this.isFavourite ? "Remove favourite" : "Add favourite";
  }

  get showCartButton() {
    // Cart defaults hidden in list mode per the compact mockup.
    return this.showCart && this.isGrid;
  }

  // --- Event helpers ------------------------------------------------------
  get eventDetail() {
    return {
      assetKey: this._assetInfo.assetKey,
      recordId: this._assetInfo.recordId
    };
  }

  fire(name, detail) {
    this.dispatchEvent(
      new CustomEvent(name, {
        detail,
        bubbles: true,
        composed: true
      })
    );
  }

  // --- Event handlers -----------------------------------------------------
  handleDownload(event) {
    event.stopPropagation();
    this.fire("download", this.eventDetail);
  }

  handleAddToCart(event) {
    event.stopPropagation();
    this.fire("addtocart", this.eventDetail);
  }

  handleFavourite(event) {
    event.stopPropagation();
    this.fire("favouritetoggle", {
      ...this.eventDetail,
      isFavourite: !this.isFavourite
    });
  }

  handleOpen() {
    this.fire("open", this.eventDetail);
  }

  handleOpenKeydown(event) {
    if (
      event.key === "Enter" ||
      event.key === " " ||
      event.key === "Spacebar"
    ) {
      event.preventDefault();
      this.handleOpen();
    }
  }
}
