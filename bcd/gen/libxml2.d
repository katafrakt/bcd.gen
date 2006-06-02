/*
 * Minimal bindings to libxml2 from D
 * 
 * for bcd.gen, the generator for bindings to C++ in D
 * 
 * this is NOT a complete binding, it's just the few functions necessary to
 * parse GCCXML output
 * 
 * Probably mostly copyright under the same license as libxml2, as it's just a
 * simple translation.
 * The translating was done by Gregor Richards.
 */

module bcd.gen.libxml2;

enum xmlAttributeType {
    XML_ATTRIBUTE_CDATA = 1,
        XML_ATTRIBUTE_ID,
        XML_ATTRIBUTE_IDREF ,
        XML_ATTRIBUTE_IDREFS,
        XML_ATTRIBUTE_ENTITY,
        XML_ATTRIBUTE_ENTITIES,
        XML_ATTRIBUTE_NMTOKEN,
        XML_ATTRIBUTE_NMTOKENS,
        XML_ATTRIBUTE_ENUMERATION,
        XML_ATTRIBUTE_NOTATION
}

enum xmlElementType {
    XML_ELEMENT_NODE=           1,
        XML_ATTRIBUTE_NODE=         2,
        XML_TEXT_NODE=              3,
        XML_CDATA_SECTION_NODE=     4,
        XML_ENTITY_REF_NODE=        5,
        XML_ENTITY_NODE=            6,
        XML_PI_NODE=                7,
        XML_COMMENT_NODE=           8,
        XML_DOCUMENT_NODE=          9,
        XML_DOCUMENT_TYPE_NODE=     10,
        XML_DOCUMENT_FRAG_NODE=     11,
        XML_NOTATION_NODE=          12,
        XML_HTML_DOCUMENT_NODE=     13,
        XML_DTD_NODE=               14,
        XML_ELEMENT_DECL=           15,
        XML_ATTRIBUTE_DECL=         16,
        XML_ENTITY_DECL=            17,
        XML_NAMESPACE_DECL=         18,
        XML_XINCLUDE_START=         19,
        XML_XINCLUDE_END=           20
}
alias xmlElementType xmlNsType;

struct _xmlAttr {
    void           *_private;   /* application data */
    xmlElementType   type;      /* XML_ATTRIBUTE_NODE, must be second ! */
    char            *name;      /* the name of the property */
    _xmlNode        *children;  /* the value of the property */
    _xmlNode        *last;      /* NULL */
    _xmlNode        *parent;    /* child->parent link */
    _xmlAttr        *next;      /* next sibling link  */
    _xmlAttr        *prev;      /* previous sibling link  */
    _xmlDoc         *doc;       /* the containing document */
    xmlNs           *ns;        /* pointer to the associated namespace */
    xmlAttributeType atype;     /* the attribute type if validating */
    void            *psvi;      /* for type/PSVI informations */
}
alias _xmlAttr xmlAttr;

struct _xmlDtd {
    void           *_private;   /* application data */
    xmlElementType  type;       /* XML_DTD_NODE, must be second ! */
    char           *name;        /* Name of the DTD */
    _xmlNode       *children;  /* the value of the property link */
    _xmlNode       *last;      /* last child link */
    _xmlDoc        *parent;    /* child->parent link */
    _xmlNode       *next;      /* next sibling link  */
    _xmlNode       *prev;      /* previous sibling link  */
    _xmlDoc        *doc;       /* the containing document */

    /* End of common part */
    void          *notations;   /* Hash table for notations if any */
    void          *elements;    /* Hash table for elements if any */
    void          *attributes;  /* Hash table for attributes if any */
    void          *entities;    /* Hash table for entities if any */
    char          *ExternalID;  /* External identifier for PUBLIC DTD */
    char          *SystemID;    /* URI for a SYSTEM or PUBLIC DTD */
    void          *pentities;   /* Hash table for param entities if any */
}
alias _xmlDtd xmlDtd;

struct _xmlDoc {
    void           *_private;   /* application data */
    xmlElementType  type;       /* XML_DOCUMENT_NODE, must be second ! */
    char           *name;       /* name/filename/URI of the document */
    _xmlNode       *children;  /* the document tree */
    _xmlNode       *last;      /* last child link */
    _xmlNode       *parent;    /* child->parent link */
    _xmlNode       *next;      /* next sibling link  */
    _xmlNode       *prev;      /* previous sibling link  */
    _xmlDoc        *doc;       /* autoreference to itself */

    /* End of common part */
    int             compression;/* level of zlib compression */
    int             standalone; /* standalone document (no external refs) */
    _xmlDtd        *intSubset; /* the document internal subset */
    _xmlDtd        *extSubset; /* the document external subset */
    _xmlNs         *oldNs;     /* Global namespace, the old way */
    char           *xmlversion;/* the XML version string */
    char           *encoding;   /* external initial encoding, if any */
    void           *ids;        /* Hash table for ID attributes if any */
    void           *refs;       /* Hash table for IDREFs attributes if any */
    char           *URL;        /* The URI for that document */
    int             charset;    /* encoding of the in-memory content
    actually an xmlCharEncoding */
    void           *dict;      /* dict used to allocate names or NULL */
    void           *psvi;       /* for type/PSVI informations */
}
alias _xmlDoc xmlDoc;

struct _xmlNode {
    void            *_private;   /* application data */
    xmlElementType   type;      /* type number, must be second ! */
    char            *name;      /* the name of the node, or the entity */
    _xmlNode        *children;  /* parent->childs link */
    _xmlNode        *last;      /* last child link */
    _xmlNode        *parent;    /* child->parent link */
    _xmlNode        *next;      /* next sibling link  */
    _xmlNode        *prev;      /* previous sibling link  */
    _xmlDoc         *doc;       /* the containing document */

    /* End of common part */
    xmlNs           *ns;        /* pointer to the associated namespace */
    char            *content;   /* the content */
    _xmlAttr        *properties;/* properties list */
    xmlNs           *nsDef;     /* namespace definitions on this node */
    void            *psvi;      /* for type/PSVI informations */
    ushort           line;      /* line number */
    ushort           extra;     /* extra data for XPath/XSLT */
}
alias _xmlNode xmlNode;

struct _xmlNs {
    _xmlNs        *next;       /* next Ns link for this node  */
    xmlNsType      type;        /* global or local */
    char          *href;        /* URL for the namespace */
    char          *prefix;      /* prefix for the namespace */
    void          *_private;   /* application data */
}
alias _xmlNs xmlNs;

extern (C) {
    void xmlCheckVersion(int);
    
    xmlDoc *xmlReadFile     (char *URL,
                             char *encoding,
                             int options);
    
    xmlNode *xmlDocGetRootElement(xmlDoc *doc);
    
    void xmlFreeDoc(xmlDoc *cur);
    
    void xmlCleanupParser();
    
    char *xmlGetProp        (xmlNode *node,
                             char *name);
}
