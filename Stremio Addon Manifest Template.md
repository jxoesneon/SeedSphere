# **The Stremio Addon Manifest: A Comprehensive Developer's Guide**

## **Section 1: The Anatomy of a Stremio Addon Manifest**

The Stremio addon manifest is the foundational blueprint for any addon within the Stremio ecosystem. It is a declarative JSON object, served from a /manifest.json endpoint, that functions as the primary communication contract between an addon's web service and the Stremio client application. Stremio's architecture is fundamentally built around these remote web services, a key design decision that distinguishes it from platforms like Kodi, where addons typically run as local scripts. This remote-service model enhances security and simplifies the user experience, as addons cannot directly harm a user's computer.

### **The Declarative Philosophy**

The manifest does not contain executable logic; rather, it *describes* the addon's identity, purpose, and technical capabilities. Stremio clients parse this descriptive information to determine if, when, and how to query the addon's other resource endpoints, such as /catalog/, /meta/, /stream/, or /subtitles/. This design promotes a clear separation of concerns, where the manifest serves as a static contract and the other endpoints provide dynamic data.  
This manifest-first, declarative architecture implies a stateless interaction model. The Stremio client does not maintain a persistent connection to an addon. Instead, it makes discrete, stateless HTTP requests to the declared resource endpoints as dictated by user actions and the manifest's contract. The introduction of user-specific configurations, which are passed as parameters in request URLs, further reinforces this model by ensuring that state is transmitted with each request rather than being maintained server-side. This stateless, request-response pattern is the hallmark of RESTful APIs and is exceptionally well-suited for modern, scalable deployment strategies, including serverless functions and lightweight web frameworks, which are often recommended in official developer guides.

### **Hosting and Accessibility Requirements**

For an addon to function correctly within the Stremio ecosystem, it must adhere to two critical technical prerequisites. Firstly, the addon's manifest and all its resources must be served over HTTPS, with the sole exception of local development servers accessed via 127.0.0.1. Secondly, the addon server must correctly implement Cross-Origin Resource Sharing (CORS) headers to allow requests from Stremio's web and desktop clients. A significant advantage for developers is that the official Stremio Addon SDKs—available for Node.js, Deno, and Go—automatically handle the complexities of CORS implementation, streamlining the development process.

## **Section 2: Core Identity Properties**

The core identity properties are the non-negotiable fields within the manifest that uniquely identify, version, and describe the addon. These properties are essential for both the Stremio system to manage the addon and for users to understand its purpose and origin. Their mandatory inclusion signals a mature ecosystem design focused on stability, accountability, and long-term maintainability. While a rudimentary plugin system might only require a name, Stremio mandates a triad of properties—a unique ID, a semantic version, and a contact email—which are common in professional software distribution platforms and create a framework for a manageable, public ecosystem of third-party developers.

### **id (String, Required)**

This property serves as the unique, machine-readable identifier for the addon, acting as its primary key within the Stremio ecosystem. To prevent collisions with other addons, the documentation strongly recommends using a reverse domain name notation, a standard software engineering practice for ensuring global uniqueness.

* **Format:** Dot-separated string.  
* **Example:** "com.stremio.filmon", "org.myexampleaddon"

### **version (String, Required)**

The addon's version number must be a valid string that adheres to the Semantic Versioning (SemVer) 2.0.0 specification. This is critical for tracking changes, debugging, and managing dependencies. While not explicitly stated as a current feature, proper versioning is a prerequisite for future capabilities like automated update notifications or compatibility checks.

* **Format:** MAJOR.MINOR.PATCH (e.g., 1.0.0).  
* **Example:** "1.0.0"

### **name (String, Required)**

This is the human-readable name of the addon that is prominently displayed throughout the Stremio user interface, including the addon catalog and installation prompts. It should be concise, descriptive, and easily recognizable to the user.

* **Example:** "Hello, World", "Official WatchHub"

### **description (String, Required)**

A more detailed, human-readable description of the addon's functionality and the content it provides. This text is shown to the user in the addon catalog and helps set clear expectations about what the addon does.

* **Example:** "My first Stremio add-on", "Aggregates content availability across Netflix, Hulu, HBO, and others."

### **contactEmail (String, Required)**

An email address for support and issue reporting. This property is functionally linked to the "Report" button within the Stremio application, providing users with a direct channel to the developer for assistance. The Stremio team may also use this email for official communications regarding the addon, making it a crucial element for maintenance and accountability.

* **Example:** "developer@example.com"

## **Section 3: Declaring Capabilities: resources, types, and idProperty**

This section constitutes the technical core of the manifest, defining the functional contract that dictates what the addon provides to the Stremio platform. Stremio's content resolution engine relies exclusively on the combination of these three properties to efficiently route user requests to the appropriate addon. This system creates a powerful and efficient content discovery mechanism, functioning as a "chain of responsibility" design pattern. When a user requests a piece of content (e.g., a movie with a specific imdb\_id), the Stremio client does not broadcast the request to every installed addon. Instead, it intelligently filters the list of available addons, querying only those whose manifests declare compatibility with the requested resource, type, and idProperty. This targeted approach avoids unnecessary network traffic and processing, demonstrating a sophisticated architectural choice designed for performance and scalability.

### **The resources Array (Array of Strings/Objects, Required)**

This array declares the functional endpoints the addon provides, representing the most fundamental statement of its capabilities. Each value in the array maps directly to an API endpoint that the addon must serve (e.g., "catalog" maps to the /catalog/... endpoint) and a corresponding handler method in the official SDKs (e.g., defineCatalogHandler). For more granular control, a resource can be declared as an object instead of a simple string. This allows for additional parameters, such as idPrefixes, which instructs Stremio to query the addon's meta resource only for items with specific ID patterns, further optimizing request routing.

### **The types Array (Array of Strings, Required)**

This array specifies the content types the addon supports, working in close conjunction with the resources array. For instance, an addon might provide the stream resource, but only for the movie and series types. Stremio uses this information to narrow down which addons to query when a user interacts with a specific piece of content.

### **The idProperty (String or Array of Strings, Required)**

This property is the crucial link that connects content within Stremio to the data provided by an addon. When a user selects a movie in the Stremio interface, the application identifies that content by a key-value pair, such as imdb\_id: "tt0017136". The client will then query addons that have explicitly declared "imdb\_id" in their idProperty array and "movie" in their types array. An addon can support multiple ID properties by providing an array of strings.  
**Table 3.1: Definitive resources Values**

| Value | Endpoint | SDK Handler | Description |
| :---- | :---- | :---- | :---- |
| catalog | /catalog/... | defineCatalogHandler | Provides lists of content (meta items) to populate Stremio's Discover and Board sections. |
| meta | /meta/... | defineMetaHandler | Provides detailed metadata for a single content item, such as description, cast, and episode lists. |
| stream | /stream/... | defineStreamHandler | Provides one or more playable streams (e.g., HTTP URLs, torrent info hashes) for a specific video. |
| subtitles | /subtitles/... | defineSubtitlesHandler | Provides subtitle files (e.g., in .srt or .vtt format) for a specific video. |

**Table 3.2: Definitive types Values**

| Value | Description |
| :---- | :---- |
| movie | Represents feature films. A meta item of this type typically provides streams directly. |
| series | Represents episodic content like TV shows. The meta item contains a videos array organized by season and episode. |
| channel | Represents a collection of videos in a single, non-seasonal list, similar to a YouTube channel. |
| tv | Represents live television streams. Sources are expected to be continuous live streams without a fixed duration. |
| other | A general-purpose type for content that does not fit into the other categories. |

## **Section 4: Crafting the User Experience: Catalogs, Presentation, and Branding**

This section details the manifest properties that control the addon's visual identity and the organization of its content within the Stremio application. These properties are crucial for creating a polished, user-friendly experience, enhancing brand recognition, and improving content discoverability. The structure of these properties reveals a design philosophy that decouples the act of *providing* content from the methods of *presenting* it. An addon can possess a single underlying dataset but expose it through numerous catalogs and sorting orders defined declaratively in the manifest. This allows developers to maximize the content's visibility and utility within the Stremio UI—creating distinct user experiences like "Popular Movies" and "New Releases" from the same data source—without needing to duplicate data or complex backend logic.

### **Visual Branding**

* **logo (String, Optional):** A URL pointing to the addon's logo. For optimal display, this should be a 256x256 pixel monochrome PNG image with a transparent background. The logo is displayed prominently in the addon catalog next to the addon's name and description.  
* **background (String, Optional):** A URL pointing to a background image used to represent the addon, often displayed on its details page. The recommended resolution is at least 1024x786 pixels, in either PNG or JPG format.

### **Building Content Feeds with catalogs**

* **catalogs (Array of Objects, Required if resources contains "catalog"):** This array is the mechanism for populating Stremio's "Discover" and "Board" sections with content rows. Each object in the array defines a single catalog and must contain at least three properties :  
  * **type (String):** The content type for this catalog (e.g., "movie", "series"). Must be one of the values declared in the top-level types array.  
  * **id (String):** A unique identifier for this specific catalog within the addon.  
  * **name (String):** The human-readable name for the catalog that will be displayed as the row title in the Stremio UI (e.g., "Trending Movies").

### **Advanced Catalog Features via extra**

* **extra (Array of Objects, Optional):** Nested within a catalog object, this property unlocks advanced discovery features by allowing the addon to accept additional parameters in catalog requests. Stremio's UI will dynamically add controls like a search bar or dropdown filters based on the extra options declared.

**Table 4.1: The extra Property for Catalogs**

| name Value | isRequired (Boolean) | Additional Properties | Functionality Enabled |
| :---- | :---- | :---- | :---- |
| "skip" | false | None | Enables **pagination**. Stremio will pass a skip parameter in the request URL, allowing the addon to return content in pages. |
| "search" | false | None | Enables **searching**. A search bar will appear in Stremio, and user queries will be passed via a search parameter. If isRequired is true, the catalog will only be used for search and will not appear on the Board or Discover pages. |
| "genre" | false | A top-level genres array (e.g., genres: \["Action", "Comedy"\]) must be defined in the same catalog object. | Enables **genre filtering**. Stremio will display a genre dropdown menu populated with the values from the genres array. |

*Note: The isRequired property must not be set to true on more than one extra item within the same catalog, as this would create a logical conflict and cause the catalog to be ignored by Stremio.*

### **Custom Sorting with sorts**

* **sorts (Array of Objects, Optional):** This property allows an addon to define alternative sorting options for its catalogs. Each sort object can specify a custom prop to sort by and a name to display to the user. These options typically appear as tabs in the Discover screen (e.g., "Trending," "By Year"), providing powerful ways for users to explore the addon's content.  
  * **Example Object:** { "prop": "popularities.moviedb", "name": "SORT\_TRENDING", "types": \["movie", "series"\] }

## **Section 5: Advanced Functionality: Configuration and Behavior**

This section explores the manifest properties that enable dynamic, personalized, and sophisticated addon functionalities. These features are particularly crucial for addons that require user-specific input, such as API keys, login credentials, or personal preferences. The introduction of these properties marks a significant evolution in the Stremio addon platform, facilitating a new class of "service integration" addons that connect Stremio to external authenticated services. This fundamentally changes the relationship between the user, the addon, and third-party platforms. Early addons were often limited to providing static or public domain content. However, many of the most powerful and popular community addons today rely on integrating with premium services like Real-Debrid and Trakt. These integrations would be impossible without a secure and standardized mechanism for users to provide their credentials. The config and behaviorHints properties are the key technical enablers for this entire ecosystem, representing a deliberate architectural decision to support complex, stateful, and personalized integrations.

### **User Settings with the config Array**

* **config (Array of Objects, Optional):** This property defines a schema for user-configurable settings. When this property is present, the Stremio client will automatically render a configuration page with input fields corresponding to the objects in the array. This is the standard method for collecting user data like API keys or preferences. Each configuration object can specify a key, title, type (e.g., "text", "password", "checkbox", "select"), and whether it is required.  
* **encryptionSecret (String, Required if config is defined):** When using the Deno SDK, if the config property is defined, this property is also required. It should be a secret key used to encrypt and decrypt sensitive user configuration data, ensuring it is handled securely.

### **Controlling Installation Flow with behaviorHints**

* **behaviorHints (Object, Optional):** This object provides metadata to the Stremio client that influences the addon's installation and configuration flow. It modifies the user interface to guide the user through any necessary setup steps.

**Table 5.1: behaviorHints Flags and UI Impact**

| Flag Combination | UI Result | Use Case |
| :---- | :---- | :---- |
| { "configurable": true } | The standard "Install" button is displayed, with a small "Configure" (gear) icon next to it. | The addon has optional settings that can be changed, but it can function with default values without initial configuration. |
| { "configurable": true, "configurationRequired": true } | The "Install" button is completely replaced by a single "Configure" button. The addon cannot be installed until the user completes the configuration process. | The addon is non-functional without user-provided data, such as a mandatory API key or login credentials. |
| { "adult": true } | The addon is marked as containing adult content. This may affect its visibility or require user confirmation depending on client settings. | The addon provides content that is not suitable for all ages. |
| { "p2p": true } | Informs the user that the addon may use peer-to-peer (P2P) technology for streaming, which may have privacy implications. | The addon provides streams via torrents or other P2P protocols. |

### **Efficient Content Matching with idPrefixes**

* **idPrefixes (Array of Strings, Optional):** This property serves as a crucial optimization filter. It is an array of string prefixes that tells Stremio to only query this addon for meta or stream information if the requested content ID begins with one of the specified prefixes. For example, an addon that only provides content from IMDb should set this to \["tt"\]. This prevents the Stremio client from sending unnecessary HTTP requests to addons that are not equipped to handle a given content ID, improving overall application performance and reducing server load.

## **Section 6: Distribution, Visibility, and Context**

This section covers the operational properties of the manifest that control how an addon is published, where it is visible, and how it adapts to the user's specific context, such as their geographical location. These properties demonstrate that the Stremio addon platform is designed not as a monolith, but as a global, multi-platform ecosystem. The existence of flags for platform-specific listing (listedOn), regional content rights (countrySpecific), and developer privacy (dontAnnounce) shows a sophisticated understanding of the technical, legal, and business complexities of a modern media application. They provide developers with the necessary controls to navigate this landscape effectively.

### **Hosting and Publishing**

* **endpoint (String, Optional):** The full, public HTTP endpoint where the hosted version of this addon can be reached. This URL should typically end in /manifest.json. When this property is present and valid, an addon server built with the official SDK will automatically attempt to announce itself to Stremio's central addon tracker, making it eligible for listing in the public addon catalog.  
* **dontAnnounce (Boolean, Optional):** If set to true, this flag prevents the addon from announcing itself to the central tracker, even if a valid endpoint is provided. This is a crucial feature for private addons, addons under development, or those intended for a limited audience.

### **Platform Visibility**

* **listedOn (Array of Strings, Optional):** This array provides granular control over which Stremio client platforms the addon will be publicly listed on. This acknowledges that the addon ecosystem is not uniform and may have different constraints or approval processes per platform (e.g., stricter rules for iOS).  
  * **Possible Values:** "web", "desktop", "android", "ios".  
  * **Default:** \["web", "desktop", "android"\].  
  * **Hiding from all catalogs:** To make an addon installable only via a direct link, pass an empty array (\`\`).

### **Contextual Content Delivery**

These boolean flags allow an addon to request additional context about the user from the Stremio client, enabling the delivery of tailored or region-specific content.

* **countrySpecific (Boolean, Optional):** If true, the Stremio client will pass the user's two-letter ISO country code along with catalog (meta.find) requests. This is essential for addons that integrate with geo-restricted services like Netflix.  
* **zipSpecific (Boolean, Optional):** If true, the client must pass the user's zip code with catalog requests. This is designed for hyper-local services, such as a cinema showtimes guide.  
* **countrySpecificStreams (Boolean, Optional):** If true, the client will pass the user's country code with stream (stream.find) requests, allowing the addon to return geo-specific stream URLs.

### **Miscellaneous Properties**

* **isFree (Boolean, Optional):** When set to true, this flag indicates that all content provided by the addon is free of charge. This information can be used by Stremio when auto-generating a landing page for the addon.  
* **suggested (Array of Strings, Optional):** An array of other addon ids that should be recommended to the user when they install this addon. This can be used for cross-promotion or to bundle complementary addons (e.g., suggesting a specific subtitle addon).  
* **searchDebounce (Number, Optional):** A client-side hint, in milliseconds, for how much time the Stremio app should wait after the user stops typing before sending a search request to the addon. This can help reduce unnecessary API calls while the user is typing their query.

## **Section 7: The Complete Manifest Template and Annotated Examples**

This final section synthesizes all the preceding information into a complete, annotated template and a series of practical examples. These artifacts serve as both a comprehensive reference and a starting point for addon development, directly addressing a wide range of use cases from simple content providers to complex, configurable service integrations.

### **The Complete, Annotated Manifest Template**

The following template includes every known property for a Stremio addon manifest. Each field is accompanied by comments explaining its data type, requirement status, and purpose.  
`{`  
  `// SECTION 1: CORE IDENTITY (All Required)`  
  `// ------------------------------------------`  
  `"id": "com.yourcompany.youraddon", // Required. String. A unique, dot-separated identifier for the addon.`  
  `"version": "1.0.0", // Required. String. The addon's version, must follow Semantic Versioning (e.g., "MAJOR.MINOR.PATCH").`  
  `"name": "My Awesome Addon", // Required. String. The human-readable name displayed in the Stremio UI.`  
  `"description": "This addon provides amazing content and demonstrates all possible manifest properties.", // Required. String. A detailed description of the addon's purpose and features.`  
  `"contactEmail": "support@yourcompany.com", // Required. String. An email address for user support and official communication. Tied to the "Report" button.`

  `// SECTION 2: CAPABILITIES (All Required)`  
  `// ------------------------------------------`  
  `"resources":,`  
      `"idPrefixes": ["tt", "custom_"]`  
    `}`  
  `],`  
  `"types": ["movie", "series", "tv", "channel"], // Required. Array of Strings. The content types this addon supports.`  
  `"idProperty": ["imdb_id", "yt_id", "custom_id"], // Required. String or Array of Strings. The ID properties this addon can resolve.`

  `// SECTION 3: USER EXPERIENCE & BRANDING (All Optional)`  
  `// ----------------------------------------------------`  
  `"logo": "https://your-cdn.com/logo_256x256.png", // Optional. String. URL to a 256x256 monochrome PNG logo.`  
  `"background": "https://your-cdn.com/background_1024x786.jpg", // Optional. String. URL to a 1024x786+ background image.`  
  `"catalogs":,`  
      `"genres": // Required if "genre" extra is used.`  
    `},`  
    `{`  
      `"type": "series",`  
      `"id": "new_series",`  
      `"name": "New Series"`  
    `}`  
  `],`  
  `"sorts":`  
    `}`  
  `],`

  `// SECTION 4: ADVANCED FUNCTIONALITY (All Optional)`  
  `// --------------------------------------------------`  
  `"config":,`  
  `"behaviorHints": { // Optional. Object. Influences addon installation and behavior.`  
    `"configurable": true, // Has settings.`  
    `"configurationRequired": true, // Must be configured before install.`  
    `"adult": false, // Does not contain adult content.`  
    `"p2p": true // May use P2P technology (e.g., torrents).`  
  `},`  
  `"idPrefixes": ["tt", "yt"], // Optional. Array of Strings. A top-level filter to only receive requests for IDs with these prefixes.`

  `// SECTION 5: DISTRIBUTION & CONTEXT (All Optional)`  
  `// ------------------------------------------------`  
  `"endpoint": "https://my-awesome-addon.com/manifest.json", // Optional. String. Public URL for auto-announcing to the central catalog.`  
  `"dontAnnounce": false, // Optional. Boolean. If true, prevents auto-announcing.`  
  `"listedOn": ["desktop", "web", "android"], // Optional. Array of Strings. Controls visibility on different Stremio platforms.`  
  `"isFree": true, // Optional. Boolean. A hint that the addon's content is free.`  
  `"suggested": ["com.stremio.opensubtitlesv3"], // Optional. Array of Strings. Suggests other addons to install.`  
  `"searchDebounce": 300, // Optional. Number. Client-side hint for search request delay in ms.`  
  `"countrySpecific": true, // Optional. Boolean. Requests user's country code for catalog queries.`  
  `"zipSpecific": false, // Optional. Boolean. Requests user's zip code for catalog queries.`  
  `"countrySpecificStreams": false // Optional. Boolean. Requests user's country code for stream queries.`  
`}`

### **Annotated Example 1: Minimalist Stream Provider**

**Use Case:** An addon that provides streams for movies from a specific public domain archive. It relies on Stremio's built-in Cinemeta addon for all metadata (posters, descriptions, etc.). It does not need its own catalogs or any user configuration.  
`{`  
  `// --- Core Identity ---`  
  `"id": "org.publicdomain.archive",`  
  `"version": "1.0.1",`  
  `"name": "Public Domain Archive",`  
  `"description": "Provides direct streams for public domain movies.",`  
  `"contactEmail": "archive-dev@example.com",`

  `// --- Capabilities ---`  
  `// This addon ONLY provides streams. It does not need "catalog" or "meta".`  
  `"resources": ["stream"],`  
  `// It supports movies.`  
  `"types": ["movie"],`  
  `// It knows how to find streams using the standard IMDb ID, which is what Cinemeta provides.`  
  `"idProperty": "imdb_id",`

  `// --- Branding ---`  
  `// A simple logo helps users identify the addon.`  
  `"logo": "https://example.com/pda_logo.png",`

  `// --- Behavior ---`  
  `// This addon uses direct HTTP streams, not P2P.`  
  `"behaviorHints": {`  
    `"p2p": false`  
  `}`  
`}`

### **Annotated Example 2: Advanced Configurable Catalog Addon**

**Use Case:** A powerful addon that provides custom, curated movie and series catalogs from a third-party service that requires a user-specific API key. It offers search functionality and must be configured before it can be used.  
`{`  
  `// --- Core Identity ---`  
  `"id": "com.thirdparty.curator",`  
  `"version": "2.5.0",`  
  `"name": "Curator Pro",`  
  `"description": "Access curated movie and series collections from the Curator service. API Key required.",`  
  `"contactEmail": "curator-pro-support@example.com",`

  `// --- Capabilities ---`  
  `// This addon provides both catalogs and the streams for the items in them.`  
  `"resources": ["catalog", "stream"],`  
  `"types": ["movie", "series"],`  
  `// It uses a custom ID format from its service.`  
  `"idProperty": "curator_id",`  
  `// This optimization ensures Stremio only asks this addon for items with the "curator_" prefix.`  
  `"idPrefixes": ["curator_"],`

  `// --- User Experience & Branding ---`  
  `"logo": "https://example.com/curator_logo.png",`  
  `"background": "https://example.com/curator_background.jpg",`  
  `"catalogs":`  
    `},`  
    `{`  
      `"type": "series",`  
      `"id": "curator_popular_series",`  
      `"name": "Popular Series"`  
    `}`  
  `],`

  `// --- Advanced Functionality ---`  
  `// Defines the required API key input field for the user.`  
  `"config":,`  
  `// This combination forces the user to configure the addon before they can install it,`  
  `// which is essential since the addon is useless without an API key.`  
  `"behaviorHints": {`  
    `"configurable": true,`  
    `"configurationRequired": true`  
  `}`  
`}`

**Table 7.1: Master Manifest Property Reference**

| Property Name | Data Type | Required/Optional | Description |
| :---- | :---- | :---- | :---- |
| id | String | Required | Unique, dot-separated identifier for the addon. |
| version | String | Required | Semantic Version of the addon. |
| name | String | Required | Human-readable name for the addon. |
| description | String | Required | Detailed description of the addon's functionality. |
| contactEmail | String | Required | Support email address. |
| resources | Array | Required | Declares the addon's capabilities (e.g., catalog, stream). |
| types | Array | Required | Declares the supported content types (e.g., movie, series). |
| idProperty | String/Array | Required | The ID key(s) the addon can resolve (e.g., imdb\_id). |
| logo | String | Optional | URL to a 256x256 monochrome PNG logo. |
| background | String | Optional | URL to a 1024x786+ background image. |
| catalogs | Array | Optional | Defines content catalogs for Discover/Board. |
| sorts | Array | Optional | Defines alternative sorting options for catalogs. |
| config | Array | Optional | Defines a schema for user-configurable settings. |
| encryptionSecret | String | Conditional | Secret key for encrypting user config (Deno SDK). |
| behaviorHints | Object | Optional | Influences addon installation and behavior (e.g., configurable). |
| idPrefixes | Array | Optional | Optimization filter for content IDs. |
| endpoint | String | Optional | Public URL for announcing the addon to the central catalog. |
| dontAnnounce | Boolean | Optional | Prevents the addon from being publicly announced. |
| listedOn | Array | Optional | Controls on which platforms the addon is listed. |
| isFree | Boolean | Optional | A hint that the addon provides free content. |
| suggested | Array | Optional | Recommends other addons to install. |
| searchDebounce | Number | Optional | Client-side search input delay in milliseconds. |
| countrySpecific | Boolean | Optional | Requests user country code for catalog queries. |
| zipSpecific | Boolean | Optional | Requests user zip code for catalog queries. |
| countrySpecificStreams | Boolean | Optional | Requests user country code for stream queries. |

### **Conclusion**

The Stremio addon manifest is a powerful, declarative contract that serves as the central nervous system of the Stremio addon ecosystem. Its design emphasizes stability, security, and a clear separation of concerns, enabling a robust platform for third-party developers. From basic identity properties to advanced configuration schemas and contextual flags, the manifest provides a comprehensive toolkit for creating a wide spectrum of addons—from simple content providers to sophisticated service integrations. A thorough understanding of every property and its interactions is paramount for any developer seeking to build efficient, user-friendly, and feature-rich addons for the Stremio platform. This guide provides the complete, consolidated reference necessary to achieve that mastery.

#### **Works cited**

1\. 1\. The add-on manifest · Stremio add-ons guide, https://stremio.github.io/stremio-addon-guide/step1 2\. The basics · Stremio add-ons guide, https://stremio.github.io/stremio-addon-guide/basics 3\. Deflix-tv/go-stremio: Stremio addon SDK for Go \- GitHub, https://github.com/Deflix-tv/go-stremio 4\. stremio-addons/docs/api/manifest.md at master \- GitHub, https://github.com/Stremio/stremio-addons/blob/master/docs/api/manifest.md 5\. Stremio/stremio-addon-sdk: A Node.js SDK for creating and publishing Stremio add-ons, https://github.com/Stremio/stremio-addon-sdk 6\. Stremio Addon with Key \- GitHub, https://github.com/Stremio/stremio-addon-with-key 7\. 5\. Deploying · Stremio add-ons guide, https://stremio.github.io/stremio-addon-guide/sdk-guide/step5 8\. Stremio/addon-helloworld: Hello World add-on for Stremio \- GitHub, https://github.com/Stremio/addon-helloworld 9\. stremio-addon-sdk \- NPM, https://www.npmjs.com/package/stremio-addon-sdk 10\. 2\. Testing the add-on · Stremio add-ons guide, https://stremio.github.io/stremio-addon-guide/step2 11\. @mkcfdc/stremio-addon-sdk \- JSR, https://jsr.io/@mkcfdc/stremio-addon-sdk 12\. 3\. Meta · Stremio add-ons guide, https://stremio.github.io/stremio-addon-guide/sdk-guide/step3 13\. How to create a Stremio addon for playing local video files? The output is in the picture. I am totally amazed. I haven't tried it yet but it looks astonishing : r/StremioAddons \- Reddit, https://www.reddit.com/r/StremioAddons/comments/10473sd/ai\_creating\_a\_stremio\_addon\_for\_playing\_local/ 14\. 3\. The catalog · Stremio add-ons guide, https://stremio.github.io/stremio-addon-guide/step3 15\. 2\. Adding catalogs · Stremio add-ons guide \- GitHub Pages, https://stremio.github.io/stremio-addon-guide/sdk-guide/step2 16\. 10 Best Stremio Addons \- RapidSeedbox, https://www.rapidseedbox.com/blog/best-stremio-addons 17\. Addon Settings · Issue \#174 · Stremio/stremio-web \- GitHub, https://github.com/Stremio/stremio-web/issues/174 18\. Stremio/addon-helloworld-python \- GitHub, https://github.com/Stremio/addon-helloworld-python 19\. How are addons published? \- Stremio Help Center, https://stremio.zendesk.com/hc/en-us/articles/360000281452-How-are-addons-published-