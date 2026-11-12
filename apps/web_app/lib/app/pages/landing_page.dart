import 'package:web/web.dart' as web;

import 'package:sparrow_kit/sparrow_kit.dart' as core;

import '../components/contact.dart';
import '../components/footer.dart';
import '../components/hero.dart';
import '../components/navbar.dart';
import '../components/services.dart';
import '../features/portfolio/portfolio_section.dart';

const _pageTitle = 'MyCompany | Independent Creative Company';
const _pageDescription =
    'An independent creative company building thoughtful brands, digital '
    'products, and experiences for people shaping what comes next.';

class CompanyLandingPage extends core.Component<void> {
  CompanyLandingPage() : super(null);

  final core.HeadManager _headManager = core.HeadManager();

  @override
  void onMount() {
    final canonicalUri = _canonicalPageUri();
    final canonicalUrl = canonicalUri.toString();
    final imageUrl = canonicalUri.resolve('og-image.svg').toString();
    final openGraph = core.OpenGraphMetadata(
      title: _pageTitle,
      type: 'website',
      url: canonicalUrl,
      image: imageUrl,
      description: _pageDescription,
      siteName: 'MyCompany',
    );
    final twitterCard = core.TwitterCardMetadata(
      card: 'summary_large_image',
      title: _pageTitle,
      description: _pageDescription,
      image: imageUrl,
    );

    _headManager.apply(
      core.HeadMetadata(
        title: _pageTitle,
        description: _pageDescription,
        canonicalUrl: canonicalUrl,
        metaTags: [
          ...openGraph.toMetaTags(),
          ...twitterCard.toMetaTags(),
        ],
        jsonLd: [
          core.OrganizationJsonLd(
            name: 'MyCompany',
            url: canonicalUrl,
            description: _pageDescription,
          ),
        ],
      ),
    );
  }

  @override
  void onDispose() {
    _headManager.dispose();
  }

  @override
  web.Node render() => core.element(
        'div',
        children: [
          core.element('style', children: [_landingPageStyles]),
          buildNavbar(),
          core.element(
            'main',
            attributes: const {'id': 'main-content'},
            children: [
              buildHero(),
              PortfolioSection(),
              buildServices(),
              buildContact(),
            ],
          ),
          buildFooter(),
        ],
      );
}

Uri _canonicalPageUri() {
  final current = Uri.base;
  final path = current.path.endsWith('/index.html')
      ? current.path.substring(0, current.path.length - 'index.html'.length)
      : current.path;

  return Uri(
    scheme: current.scheme,
    userInfo: current.userInfo,
    host: current.host,
    port: current.hasPort ? current.port : null,
    path: path.isEmpty ? '/' : path,
  );
}

const _landingPageStyles = '''
:root {
  color-scheme: dark;
  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  background: #0b1220;
  color: #f3f6fb;
  font-synthesis: none;
  text-rendering: optimizeLegibility;
  scroll-behavior: smooth;
  --page: #0b1220;
  --panel: #111b2b;
  --panel-soft: #172338;
  --text: #f3f6fb;
  --muted: #a5b1c2;
  --line: rgba(158, 177, 201, .16);
  --accent: #8fb4e8;
}

* { box-sizing: border-box; }
body { margin: 0; min-width: 320px; background: var(--page); color: var(--text); font-size: 15px; line-height: 1.6; }
a { color: inherit; text-decoration: none; }
a:focus-visible { outline: 2px solid var(--accent); outline-offset: 5px; }
::selection { color: #0b1220; background: var(--accent); }
.shell { width: min(1120px, calc(100% - 48px)); margin-inline: auto; }
.section-anchor { scroll-margin-top: 88px; }
.site-header { position: sticky; top: 0; z-index: 20; border-bottom: 1px solid var(--line); background: rgba(11, 18, 32, .92); backdrop-filter: blur(16px); }
.navbar { min-height: 72px; display: flex; align-items: center; justify-content: space-between; gap: 28px; }
.brand { display: inline-flex; align-items: center; gap: 11px; flex-shrink: 0; }
.brand-mark { width: 32px; height: 32px; display: grid; place-items: center; border: 1px solid rgba(143, 180, 232, .35); border-radius: 8px; color: var(--accent); background: var(--panel-soft); font-size: 14px; font-weight: 750; }
.brand-name { font-size: 12px; font-weight: 700; letter-spacing: .12em; }
.nav-links { display: flex; align-items: center; justify-content: center; gap: clamp(18px, 3vw, 42px); }
.nav-links a, .nav-cta { color: #c2ccda; font-size: 13px; transition: color .2s ease, border-color .2s ease, background .2s ease; }
.nav-links a:hover, .footer-link:hover { color: var(--accent); }
.nav-cta { display: inline-flex; align-items: center; gap: 12px; padding: 10px 15px; border: 1px solid #34445b; border-radius: 6px; color: var(--text); }
.nav-cta:hover { border-color: var(--accent); color: var(--accent); }
.hero { position: relative; overflow: hidden; min-height: 590px; display: flex; flex-direction: column; justify-content: center; padding: 72px 0 28px; border-bottom: 1px solid var(--line); }
.hero::before { content: ""; position: absolute; width: 540px; height: 540px; top: -230px; right: -150px; pointer-events: none; background: radial-gradient(circle, rgba(90, 133, 190, .12), transparent 70%); }
.hero-grid { position: relative; display: grid; grid-template-columns: 1.08fr .92fr; align-items: center; gap: 56px; }
.hero-copy { max-width: 620px; }
.eyebrow { margin: 0 0 18px; color: var(--accent); font-size: 11px; font-weight: 650; letter-spacing: .11em; text-transform: uppercase; }
h1, h2, h3, p { margin-top: 0; }
.hero h1 { max-width: 640px; margin-bottom: 22px; font-size: clamp(42px, 5.2vw, 64px); font-weight: 650; letter-spacing: -.045em; line-height: 1.08; }
.text-accent { color: var(--accent); }
.hero-description { max-width: 500px; margin-bottom: 28px; color: var(--muted); font-size: 16px; line-height: 1.75; }
.hero-actions { display: flex; flex-wrap: wrap; align-items: center; gap: 25px; }
.button { display: inline-flex; min-height: 46px; align-items: center; justify-content: center; padding: 0 18px; border-radius: 6px; font-size: 13px; font-weight: 650; transition: transform .2s ease, background .2s ease, border-color .2s ease; }
.button:hover { transform: translateY(-1px); }
.button-primary { color: #0b1220; background: var(--accent); }
.button-primary:hover { background: #a8c8f2; }
.text-link { display: inline-flex; align-items: center; gap: 11px; color: var(--text); font-size: 13px; font-weight: 650; }
.text-link:hover { color: var(--accent); }
.hero-proof { display: flex; align-items: center; gap: 10px; margin-top: 38px; color: var(--muted); font-size: 12px; }
.proof-dot { width: 8px; height: 8px; border-radius: 50%; background: #79a3d8; }
.hero-artwork { position: relative; min-height: 390px; display: grid; place-items: center; isolation: isolate; }
.art-orbit { position: absolute; border: 1px solid rgba(143, 180, 232, .12); border-radius: 50%; }
.orbit-one { width: 350px; height: 350px; transform: rotate(-24deg) scaleY(.72); }
.orbit-two { width: 290px; height: 290px; transform: rotate(38deg) scaleY(.72); }
.art-card { position: absolute; display: flex; flex-direction: column; justify-content: space-between; padding: 22px; border: 1px solid rgba(190, 207, 228, .2); border-radius: 12px; box-shadow: 0 24px 64px rgba(0,0,0,.3); }
.art-card-back { z-index: -1; width: 250px; height: 300px; transform: translate(42px,-12px) rotate(3deg); color: #dce7f6; background: linear-gradient(145deg, #1d2c41, #142033); }
.art-card-back span, .art-card-label { font-size: 9px; font-weight: 800; letter-spacing: .15em; }
.art-card-back strong { max-width: 180px; font-size: 27px; font-weight: 650; letter-spacing: -.035em; line-height: 1.12; }
.art-card-front { z-index: 1; width: 260px; height: 326px; transform: translate(-15px, 18px); background: linear-gradient(150deg, #17253a, #101a2a 65%); }
.art-card-label { color: var(--accent); }
.art-shape { position: relative; width: 142px; height: 142px; align-self: center; display: grid; place-items: center; border: 1px solid rgba(143, 180, 232, .55); border-radius: 22px; background: linear-gradient(145deg, rgba(93, 133, 185, .3), rgba(24, 39, 61, .65)); }
.art-shape span { color: #c3d7f2; font-size: 58px; font-weight: 650; letter-spacing: -.06em; }
.art-card-caption { display: flex; flex-direction: column; gap: 5px; }
.art-card-caption strong { font-size: 13px; }
.art-card-caption span { color: var(--muted); font-size: 10px; }
.art-sticker { position: absolute; right: 3%; bottom: 1%; z-index: 2; display: flex; align-items: center; justify-content: center; padding: 9px 12px; border: 1px solid #344a67; border-radius: 8px; color: #dce7f6; background: #17263a; font-size: 9px; font-weight: 700; letter-spacing: .08em; white-space: nowrap; }
.hero-bottom { position: relative; display: flex; justify-content: space-between; margin-top: 46px; color: #8190a4; font-size: 10px; letter-spacing: .08em; text-transform: uppercase; }
.portfolio, .services { padding: 96px 0 104px; border-bottom: 1px solid var(--line); }
.section-heading { display: flex; align-items: end; justify-content: space-between; gap: 35px; margin-bottom: 40px; }
.section-heading h2, .contact h2 { max-width: 720px; margin-bottom: 14px; font-size: clamp(30px, 3.8vw, 44px); font-weight: 620; letter-spacing: -.04em; line-height: 1.14; }
.section-description { max-width: 540px; margin-bottom: 0; color: var(--muted); font-size: 15px; line-height: 1.7; }
.section-heading > .text-link { margin-bottom: 7px; flex-shrink: 0; }
.project-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 20px; }
.project-card { min-width: 0; }
.portfolio-filters { display: flex; flex-wrap: wrap; gap: 8px; margin: 30px 0; }
.portfolio-filter { padding: 8px 12px; border: 1px solid var(--line); border-radius: 999px; color: var(--muted); background: transparent; font: inherit; font-size: 11px; cursor: pointer; }
.portfolio-filter[aria-pressed="true"] { border-color: var(--accent); color: var(--text); background: var(--panel-soft); }
.portfolio-status { min-height: 1.5em; margin: 0 0 20px; color: var(--muted); font-size: 12px; }
.portfolio-error { color: #ffb4a2; }
.portfolio-retry { padding: 7px 11px; border: 1px solid var(--line); border-radius: 5px; color: var(--text); background: var(--panel-soft); font: inherit; font-size: 11px; cursor: pointer; }
.project-art { position: relative; overflow: hidden; min-height: 290px; display: grid; place-items: center; border: 1px solid var(--line); border-radius: 10px; }
.project-art-amber { color: #e8eef7; background: linear-gradient(145deg, #1a2a3f, #142034); }
.project-art-lilac { color: #e8eef7; background: linear-gradient(145deg, #1d2b40, #172238); }
.project-art-green { color: #e8eef7; background: linear-gradient(145deg, #192c3b, #142232); }
.project-art::before, .project-art::after { content: ""; position: absolute; border: 1px solid rgba(204, 220, 241, .14); border-radius: 50%; }
.project-art::before { width: 230px; height: 230px; }
.project-art::after { width: 280px; height: 280px; }
.art-index { position: absolute; top: 19px; left: 19px; z-index: 1; font-size: 10px; font-weight: 700; }
.project-art-object { position: relative; z-index: 1; width: 150px; height: 176px; display: grid; place-items: center; border: 1px solid rgba(194, 214, 240, .28); border-radius: 12px; background: linear-gradient(145deg, rgba(117, 153, 200, .22), rgba(25, 42, 64, .82)); box-shadow: 0 22px 50px rgba(0,0,0,.24); font-size: 28px; font-weight: 700; letter-spacing: -.04em; transition: transform .25s ease, border-color .25s ease; }
.project-card:hover .project-art-object { transform: translateY(-4px); border-color: rgba(194, 214, 240, .55); }
.project-art-caption { position: absolute; right: 18px; bottom: 18px; z-index: 1; font-size: 10px; font-weight: 650; }
.project-info { padding: 18px 2px 0; }
.project-category { color: #9dbbe4; font-size: 10px; font-weight: 650; letter-spacing: .09em; }
.project-info h3 { margin: 9px 0 7px; font-size: 18px; font-weight: 620; letter-spacing: -.02em; }
.project-info h3 a:hover { color: var(--accent); }
.project-description { max-width: 350px; margin-bottom: 0; color: var(--muted); font-size: 13px; line-height: 1.7; }
.services { background: #0e1726; }
.service-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); border-top: 1px solid var(--line); border-bottom: 1px solid var(--line); }
.service-card { min-height: 275px; padding: 27px 25px 25px 0; }
.service-card + .service-card { padding-left: 25px; border-left: 1px solid var(--line); }
.service-card-top { display: flex; align-items: center; justify-content: space-between; margin-bottom: 42px; }
.service-number { color: var(--accent); font-size: 11px; font-weight: 700; }
.service-arrow { color: #8998ad; font-size: 17px; }
.service-card h3 { margin-bottom: 12px; font-size: 19px; font-weight: 620; letter-spacing: -.02em; }
.service-description { min-height: 66px; margin-bottom: 19px; color: var(--muted); font-size: 13px; line-height: 1.7; }
.service-list { margin-bottom: 0; color: #c2ccda; font-size: 11px; letter-spacing: .01em; }
.contact { padding: 84px 0; }
.contact-panel { display: flex; align-items: end; justify-content: space-between; gap: 50px; padding: 50px; border: 1px solid #2a3a50; border-radius: 12px; background: linear-gradient(120deg, rgba(31, 51, 77, .44), rgba(17, 27, 43, .95) 58%), var(--panel); }
.contact-copy { max-width: 650px; }
.contact h2 { margin-bottom: 17px; }
.contact-description { max-width: 480px; margin-bottom: 0; color: var(--muted); font-size: 14px; line-height: 1.75; }
.contact-action { display: flex; flex-direction: column; align-items: flex-start; gap: 13px; flex-shrink: 0; }
.contact-email { color: var(--muted); font-size: 11px; }
.site-footer { padding: 56px 0 22px; border-top: 1px solid var(--line); background: #080e18; }
.footer-main { display: grid; grid-template-columns: 1.6fr .7fr .8fr; gap: 70px; padding-bottom: 55px; }
.footer-brand { margin-bottom: 18px; }
.footer-summary { max-width: 300px; margin-bottom: 0; color: #94a1b4; font-size: 12px; line-height: 1.75; }
.footer-links-group { display: flex; flex-direction: column; align-items: flex-start; gap: 12px; }
.footer-heading { margin: 3px 0 6px; color: #8998ad; font-size: 10px; font-weight: 700; letter-spacing: .1em; text-transform: uppercase; }
.footer-link, .footer-links-group > a { color: #c2ccda; font-size: 12px; }
.footer-location { color: #94a1b4; font-size: 11px; line-height: 1.6; }
.footer-bottom { display: flex; justify-content: space-between; gap: 20px; padding-top: 19px; border-top: 1px solid var(--line); color: #8190a4; font-size: 10px; }
@media (max-width: 820px) {
  .hero { min-height: auto; padding-top: 75px; }
  .hero-grid { grid-template-columns: 1fr; gap: 20px; }
  .hero-artwork { min-height: 370px; }
  .hero-bottom { margin-top: 30px; }
  .project-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .project-card:last-child { grid-column: 1 / -1; }
  .project-card:last-child .project-art { min-height: 280px; }
  .contact-panel { align-items: flex-start; flex-direction: column; padding: 42px; }
  .footer-main { gap: 35px; }
}
@media (max-width: 600px) {
  .shell { width: min(100% - 36px, 480px); }
  .navbar { min-height: 68px; flex-wrap: wrap; gap: 0; padding-block: 12px; }
  .brand-name { font-size: 10px; }
  .nav-cta { padding: 9px 10px; font-size: 11px; }
  .nav-links { order: 3; width: 100%; justify-content: space-between; gap: 8px; padding-top: 14px; }
  .nav-links a { font-size: 11px; }
  .hero { padding-top: 60px; }
  .hero h1 { font-size: clamp(40px, 11vw, 56px); }
  .hero-description { font-size: 15px; }
  .hero-proof { margin-top: 35px; }
  .hero-artwork { min-height: 330px; transform: scale(.88); }
  .hero-bottom { font-size: 8px; letter-spacing: .06em; }
  .portfolio, .services { padding: 78px 0; }
  .section-heading { align-items: flex-start; flex-direction: column; gap: 22px; margin-bottom: 32px; }
  .section-heading h2, .contact h2 { font-size: 34px; }
  .project-grid, .service-grid { grid-template-columns: 1fr; }
  .project-card:last-child { grid-column: auto; }
  .project-art, .project-card:last-child .project-art { min-height: 300px; }
  .service-card, .service-card + .service-card { min-height: auto; padding: 24px 0; border-left: 0; }
  .service-card + .service-card { border-top: 1px solid var(--line); }
  .service-card-top { margin-bottom: 26px; }
  .service-description { min-height: 0; }
  .contact { padding: 65px 0; }
  .contact-panel { gap: 30px; padding: 29px 24px; }
  .footer-main { grid-template-columns: 1fr 1fr; gap: 35px 20px; }
  .footer-about { grid-column: 1 / -1; }
  .footer-bottom { align-items: flex-start; flex-direction: column; gap: 9px; }
}
''';
