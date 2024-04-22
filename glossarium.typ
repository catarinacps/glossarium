/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.*/

// glossarium figure kind
#let __glossarium_figure = "glossarium_entry"
// prefix of label for references query
#let __glossary_label_prefix = "glossary:"
// global state containing the glossary entry and their location
#let __glossary_entries = state("__glossary_entries", (:))

#let __query_labels_with_key(loc, key, before: false) = {
  let labels = selector(label(__glossary_label_prefix + key))

  if before { labels = labels.before(loc, inclusive: false) }

  query(labels, loc)
}

#let __display_gls(short, suffix, long) = {
  short + suffix
  if long != none [ (#emph(long))]
}

#let __display_print_glossary(short, long, desc) = {
  strong(emph(short))
  if long != none [ -- #strong(long)]
  if desc != none [: #desc] else [.]
}

// Reference a term
#let gls(key, suffix: none, show-long: none, display: __display_gls) = context {
  if display == none { return [] }

  let __glossary_entries = __glossary_entries.final(here())
  let show-long = show-long

  if key in __glossary_entries {
    let (short, long,) = __glossary_entries.at(key)

    if show-long == none {
      show-long = __query_labels_with_key(here(), key, before: true).len() == 0
    }

    if not show-long { long = none }

    [
      #link(label(key), display(short, suffix, long))
      #label(__glossary_label_prefix + key)
    ]
  } else {
    text(fill: red)[Glossary entry not found: #key]
  }
}

// reference to term with pluralisation
#let glspl = gls.with(suffix: "s")

// show rule to make the references for glossarium
#let make-glossary(display: __display_gls, body) = {
  show ref: r => {
    if r.element != none and r.element.func() == figure and r.element.kind == __glossarium_figure {
      // call to the general citing function
      gls(str(r.target), suffix: r.citation.supplement, display: display)
    } else {
      r
    }
  }

  {
    body
  }
}

#let __normalize_entry_list(entry-list) = {
  entry-list.map(entry => (
    key: entry.key,
    short: entry.short,
    long: entry.at("long", default: none),
    desc: entry.at("desc", default: none),
    group: entry.at("group", default: ""),
  ))
}

#let print-glossary(entry-list, show-all: false, disable-back-references: false, enable-group-pagebreak: false, display: __display_print_glossary) = {
  let all_entries = __normalize_entry_list(entry-list).sorted(key: e => e.group)

  __glossary_entries.update(
    all_entries.fold((:), (acc, item) => { acc.insert(item.key, item); acc })
  )

  // group-by using `group` as the key
  let groups = all_entries.fold(("": ()), (acc, item) => {
    let a = acc.at(item.group, default: ())
    a.push(item)
    acc.insert(item.group, a)
    acc
  })

  for (group, entries) in groups {
    if group != "" { heading(group, level: 2) }

    for (key, short, long, desc,) in entries.sorted(key: e => e.short) {
      show figure.where(kind: __glossarium_figure): it => it.caption

      par(hanging-indent: 1em, first-line-indent: 0em)[
        #figure(
          supplement: "",
          kind: __glossarium_figure,
          numbering: none,
          caption: {
            context {
              let term_references = __query_labels_with_key(here(), key)

              if term_references.len() > 0 or show-all {
                display(short, long, desc)

                if not disable-back-references {
                  [ ]
                  term_references.map(x => x.location()).sorted(key: x => x.page()).fold(
                    (values: (), pages: ()),
                    ((values, pages), x) => if pages.contains(x.page()) {
                      (values: values, pages: pages)
                    } else {
                      values.push(x)
                      pages.push(x.page())
                      (values: values, pages: pages)
                    },
                  ).values.map(x => link(x)[#numbering(x.page-numbering(), ..counter(page).at(x))]).join(", ")
                }
              }
            }
          },
        )[] #label(key)
      ]
      parbreak()
    }
    if enable-group-pagebreak { pagebreak(weak: true) }
  }
}
