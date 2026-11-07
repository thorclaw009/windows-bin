(function () {
    "use strict";

    console.log("iBooks.to adblock detection removed");

    // Add custom banner
    const banner = document.createElement("div");
    banner.id = "ibooks-extension-banner";
    banner.textContent = "AdBlock Detection Removed by Edge Extension";

    document.body.prepend(banner);

    // // Example style modification
    // document.body.style.backgroundColor = "#f7f7f7";

    // // Remove common ad elements
    // const adSelectors = [
    //     ".advertisement",
    //     ".ads",
    //     ".banner-ad",
    //     "#ads",
    //     "[id*='ad']"
    // ];

    // adSelectors.forEach(selector => {
    //     document.querySelectorAll(selector).forEach(el => {
    //         el.remove();
    //     });
    // });

    const container = document.querySelector('.container');
    let prev = container.prevElementSibling;
    while(prev) {
        prev.remove();
        prev = container.prevElementSibling;
    }

    let next = container.nextElementSibling;
    while(next) {
        next.remove();
        next = container.nextElementSibling;
    }

    // Watch for dynamically added content
    const observer = new MutationObserver(() => {
        const container = document.querySelector('.container');
        let prev = container.prevElementSibling;
        while(prev) {
            prev.remove();
            prev = container.prevElementSibling;
        }
        let next = container.nextElementSibling;
        while(next) {
            next.remove();
            next = container.nextElementSibling;
        }
    });

    observer.observe(document.body, {
        childList: true,
        subtree: true
    });
})();