import {defineConfig} from 'vitepress'

const MCP_ENDPOINT = 'https://bpmcp.vse.cz'
const GITHUB_REPO = 'https://github.com/H7KZ/BPMCP'

export default defineConfig({
	title: 'InSIS MCP',
	cleanUrls: true,
	lastUpdated: true,
	metaChunk: true,

	sitemap: {
		hostname: MCP_ENDPOINT
	},

	themeConfig: {
		socialLinks: [{icon: 'github', link: GITHUB_REPO}],
		search: {
			// Local mini search
			provider: 'local'
		}
	},

	locales: {
		root: {
			label: 'English',
			lang: 'en',
			description: 'Read-only VŠE InSIS course, timetable and study-plan data for your AI assistant, over the Model Context Protocol.',
			themeConfig: {
				nav: [
					{text: 'Guide', link: '/guide/getting-started', activeMatch: '/guide/'},
					{text: 'Connect', link: '/guide/connecting'}
				],
				sidebar: {
					'/guide/': [
						{
							text: 'Introduction',
							items: [
								{text: 'Getting started', link: '/guide/getting-started'},
								{text: 'Connecting a client', link: '/guide/connecting'}
							]
						}
					]
				},
				editLink: {
					pattern: `${GITHUB_REPO}/edit/main/docs/:path`,
					text: 'Edit this page on GitHub'
				},
				docFooter: {
					prev: 'Previous',
					next: 'Next'
				}
			}
		},

		cs: {
			label: 'Čeština',
			lang: 'cs',
			link: '/cs/',
			description: 'Read-only data o předmětech, rozvrzích a studijních plánech z VŠE InSIS pro vašeho AI asistenta, přes Model Context Protocol.',
			themeConfig: {
				nav: [
					{text: 'Průvodce', link: '/cs/guide/getting-started', activeMatch: '/cs/guide/'},
					{text: 'Připojení', link: '/cs/guide/connecting'}
				],
				sidebar: {
					'/cs/guide/': [
						{
							text: 'Úvod',
							items: [
								{text: 'Začínáme', link: '/cs/guide/getting-started'},
								{text: 'Připojení klienta', link: '/cs/guide/connecting'}
							]
						}
					]
				},
				editLink: {
					pattern: `${GITHUB_REPO}/edit/main/docs/:path`,
					text: 'Upravit tuto stránku na GitHubu'
				},
				docFooter: {
					prev: 'Předchozí',
					next: 'Další'
				},
				outline: {label: 'Na této stránce'},
				lastUpdatedText: 'Aktualizováno',
				returnToTopLabel: 'Zpět nahoru',
				darkModeSwitchLabel: 'Vzhled',
				lightModeSwitchTitle: 'Přepnout na světlý režim',
				darkModeSwitchTitle: 'Přepnout na tmavý režim'
			}
		}
	}
})
