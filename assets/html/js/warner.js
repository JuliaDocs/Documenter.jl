function maybeAddWarning () {
    // DOCUMENTER_NEWEST is defined in versions.js, DOCUMENTER_CURRENT_VERSION in siteinfo.js
    if (window.DOCUMENTER_NEWEST && window.DOCUMENTER_CURRENT_VERSION ) {
        if (!/v(\d+\.)*\d+/.test(window.DOCUMENTER_CURRENT_VERSION)) {
            // Current version is not a version number, so we can't tell if it's the newest version. Abort.
            return
        }
        if (window.DOCUMENTER_NEWEST !== window.DOCUMENTER_CURRENT_VERSION) {
            // Only add a warning to old versions.
            return
        }
        // Add a noindex meta tag (unless one exists) so that search engines don't index this version of the docs.
        if (document.body.querySelector('meta[name="robots"]') === null) {
            const meta = document.createElement('meta');
            meta.name = 'robots';
            meta.content = 'noindex';

            document.getElementsByTagName('head')[0].appendChild(meta);
        };

        const div = document.createElement('div');
        div.setAttribute('style', 'position: fixed; width: 100%; top: 0; left: 0; box-shadow: 0 0 10px rgba(0,0,0,0.3); z-index: 999; background-color: #ffaf9c; color: rgba(0, 0, 0, 0.7); border-bottom: 1px solid #d54625; padding: 10px 35px; text-align: center; font-size: 15px;');
        const closer = document.createElement('div');
        closer.setAttribute('style', 'position: absolute; top: calc(50% - 8px); right: 18px; cursor: pointer; width: 12px;');
        // Icon by font-awesome (license: https://fontawesome.com/license, link: https://fontawesome.com/icons/times?style=solid)
        closer.innerHTML = '<svg aria-hidden="true" focusable="false" data-prefix="fas" data-icon="times" class="svg-inline--fa fa-times fa-w-11" role="img" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 352 512"><path fill="currentColor" d="M242.72 256l100.07-100.07c12.28-12.28 12.28-32.19 0-44.48l-22.24-22.24c-12.28-12.28-32.19-12.28-44.48 0L176 189.28 75.93 89.21c-12.28-12.28-32.19-12.28-44.48 0L9.21 111.45c-12.28 12.28-12.28 32.19 0 44.48L109.28 256 9.21 356.07c-12.28 12.28-12.28 32.19 0 44.48l22.24 22.24c12.28 12.28 32.2 12.28 44.48 0L176 322.72l100.07 100.07c12.28 12.28 32.2 12.28 44.48 0l22.24-22.24c12.28-12.28 12.28-32.19 0-44.48L242.72 256z"></path></svg>';
        closer.addEventListener('click', function () {
            document.body.removeChild(div);
        });
        const href = window.documenterBaseURL + '/../' + window.DOCUMENTER_NEWEST;
        div.innerHTML = 'This is an old version of the documentation. <br> <a href="' + href + '" style="color: green">Go to the newest version</a>.';
        div.appendChild(closer);
        document.body.appendChild(div);
    };
};

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', maybeAddWarning);
} else {
    maybeAddWarning();
};
