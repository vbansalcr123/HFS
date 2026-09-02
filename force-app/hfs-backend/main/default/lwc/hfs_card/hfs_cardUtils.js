/**
 * cardUtils — payload reference for `hfs_card`
 * ============================================
 * This file just documents the SHAPE of the payload a parent/container passes
 * down to `c-hfs_card`. It is a reference for future developers — no helper
 * logic, just the structure and an example.
 *
 * The card takes three `@api` props:
 *   <c-hfs_card
 *       asset-info={row.assetInfo}
 *       actions={row.actions}
 *       selected={row.selected}>
 *   </c-hfs_card>
 *
 * A parent typically holds an array of rows, one per card, keyed by recordId.
 *
 * EXAMPLE PAYLOAD (one row)
 * -------------------------
 *   {
 *       recordId: 'a010x00000AAA001',
 *       selected: false,
 *       assetInfo: {
 *           recordId:   'a010x00000AAA001',
 *           assetKey:   'a010x00000AAA001',   // echoed back on every event
 *           title:      'Q3 Brand Campaign Hero',
 *           imageUrl:   'https://.../hero-q3.jpg',
 *           imageAlt:   'Hero banner for Q3 brand campaign',
 *           layout:     'grid',               // 'grid' | 'list'
 *           isNew:      true,
 *           isFavourite:false,
 *           categoryPills: [                  // { text, colour? }
 *               { text: 'Campaign', colour: 'green' },
 *               { text: 'Hero',     colour: 'blue'  }
 *           ],
 *           metaLines: [                      // { text, warning? }
 *               { text: '4000 × 2000' },
 *               { text: 'JPG · 2.4 MB' },
 *               { text: 'Licence expiring', warning: true }
 *           ]
 *       },
 *       actions: {                            // all optional; card defaults these
 *           showDownload: true,
 *           downloadLabel: 'Download',
 *           downloadDisabled: false,
 *           showCart: true,
 *           cartLabel: 'Add to cart',
 *           cartDisabled: false,
 *           showFavourite: true,
 *           showFavouriteOnMedia: true
 *       }
 *   }
 *
 * FIELD REFERENCE
 * ---------------
 * assetInfo (asset-info prop) — record content + state:
 *   recordId       string   Salesforce record Id (identity + echoed on events).
 *   assetKey       string   Stable key echoed on every event; usually = recordId.
 *   title          string   Card heading.
 *   imageUrl       string   Media URL; media area hidden when absent.
 *   imageAlt       string   Alt text; falls back to title.
 *   layout         string   'grid' | 'list'. Defaults to 'grid'.
 *   isNew          boolean  Shows the NEW pill.
 *   isFavourite    boolean  Drives the favourite star pressed state.
 *   categoryPills  array    [{ text, colour? }]; colour falls back to 'neutral'.
 *   metaLines      array    [{ text, warning? }].
 *
 * actions (actions prop) — button config, all optional:
 *   showDownload          boolean  Default true.
 *   downloadLabel         string   Default 'Download'.
 *   downloadDisabled      boolean  Default false.
 *   showCart              boolean  Default true (still hidden in 'list' layout).
 *   cartLabel             string   Default 'Cart'.
 *   cartDisabled          boolean  Default false.
 *   showFavourite         boolean  Default true.
 *   showFavouriteOnMedia  boolean  Default true.
 *
 * selected (selected prop) — boolean, transient selection highlight.
 *
 * EVENTS emitted back to the parent (each detail carries { assetKey, recordId };
 * favouritetoggle also adds isFavourite):
 *   download, addtocart, favouritetoggle, open
 */
