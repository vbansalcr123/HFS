#!/usr/bin/env python3
"""Split a sfdx-git-delta package.xml into a schema-only manifest (CustomObject/CustomField)
and a manifest for everything else.

Used by .github/workflows/deploy.yml's "Compute Delta" step to implement the two-phase deploy:
schema is deployed for real (Phase 1) before Apex/tests validate against it (Phase 2), since a
checkOnly validate that bundles new schema with Apex tests depending on that schema silently runs
zero tests (the schema never truly exists mid-transaction for the test run to execute against).

Usage: split_delta_package.py <input package.xml> <output schema manifest> <output rest manifest>
"""

import sys
import xml.etree.ElementTree as ET

NS = "http://soap.sforce.com/2006/04/metadata"
SCHEMA_TYPES = {"CustomObject", "CustomField"}


def qname(tag):
    return f"{{{NS}}}{tag}"


def build_package(types, version_elem):
    pkg = ET.Element(qname("Package"))
    for t in types:
        pkg.append(t)
    if version_elem is not None:
        pkg.append(version_elem)
    return ET.ElementTree(pkg)


def main():
    input_path, schema_out_path, rest_out_path = sys.argv[1:4]

    ET.register_namespace("", NS)
    tree = ET.parse(input_path)
    root = tree.getroot()

    types_elems = root.findall(qname("types"))
    version_elem = root.find(qname("version"))

    schema_types = [t for t in types_elems if t.find(qname("name")).text in SCHEMA_TYPES]
    rest_types = [t for t in types_elems if t.find(qname("name")).text not in SCHEMA_TYPES]

    build_package(schema_types, version_elem).write(
        schema_out_path, xml_declaration=True, encoding="UTF-8"
    )
    build_package(rest_types, version_elem).write(
        rest_out_path, xml_declaration=True, encoding="UTF-8"
    )

    print(
        f"--- Split: {len(schema_types)} schema type(s) (CustomObject/CustomField), "
        f"{len(rest_types)} other type(s) ---"
    )


if __name__ == "__main__":
    main()
