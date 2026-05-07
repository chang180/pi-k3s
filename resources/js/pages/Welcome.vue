<script setup lang="ts">
import { Head, Link } from '@inertiajs/vue3';
import { Activity, Box, Cpu, Github, Layers, ScanLine, Sparkles, Zap } from 'lucide-vue-next';
import { calculate, dashboard, login, register } from '@/routes';

withDefaults(
    defineProps<{
        canRegister: boolean;
    }>(),
    {
        canRegister: true,
    },
);

const features = [
    {
        icon: ScanLine,
        title: '蒙地卡羅可視化',
        description: '在四分之一圓中均勻撒點，圓內 / 圓外比例即可估算 π。Canvas 即時繪製數萬個樣本點。',
    },
    {
        icon: Layers,
        title: 'K8s HPA 自動擴展',
        description: '當計算負載讓 CPU 突破門檻，K3s HPA 會自動擴增 Pod 副本，分擔計算工作。',
    },
    {
        icon: Cpu,
        title: '1C1G 友善部署',
        description: '專為最小型 VPS 調校：K3s 輕量化、PHP-FPM 2 worker、SQLite、自動 swap。',
    },
];

const steps = [
    { num: '01', title: '隨機投點', desc: '在 [0,1)² 區間以均勻分布產生 N 個點' },
    { num: '02', title: '判定圓內', desc: '若 x² + y² ≤ 1 則點落在四分之一圓內' },
    { num: '03', title: '計算 π', desc: 'π ≈ 4 × (圓內點數 / 總點數)，N 越大越收斂' },
    { num: '04', title: '分散擴展', desc: '分散式模式下，多個 Pod 各算一段，HPA 視 CPU 負載擴縮' },
];
</script>

<template>
    <Head title="Pi-K3s — 在 K3s 上看見 π 的誕生" />

    <div class="relative min-h-screen overflow-hidden bg-linear-to-b from-white via-white to-indigo-50/30 text-neutral-900 dark:from-neutral-950 dark:via-neutral-950 dark:to-indigo-950/20 dark:text-neutral-100">
        <!-- Decorative grid -->
        <div class="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top,rgba(99,102,241,0.08),transparent_60%)] dark:bg-[radial-gradient(circle_at_top,rgba(99,102,241,0.15),transparent_60%)]" />

        <!-- Top nav -->
        <header class="relative z-10 mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
            <div class="flex items-center gap-2 font-semibold">
                <span class="grid size-8 place-items-center rounded-lg bg-linear-to-br from-indigo-500 to-purple-500 text-white">π</span>
                <span class="text-lg">Pi-K3s</span>
            </div>
            <nav class="flex items-center gap-2 text-sm">
                <Link
                    v-if="$page.props.auth.user"
                    :href="dashboard()"
                    class="rounded-md border border-neutral-200 px-4 py-1.5 transition-colors hover:bg-neutral-100 dark:border-neutral-800 dark:hover:bg-neutral-900"
                >
                    儀表板
                </Link>
                <template v-else>
                    <Link
                        :href="login()"
                        class="rounded-md px-4 py-1.5 transition-colors hover:bg-neutral-100 dark:hover:bg-neutral-900"
                    >
                        登入
                    </Link>
                    <Link
                        v-if="canRegister"
                        :href="register()"
                        class="rounded-md border border-neutral-200 px-4 py-1.5 transition-colors hover:bg-neutral-100 dark:border-neutral-800 dark:hover:bg-neutral-900"
                    >
                        註冊
                    </Link>
                </template>
            </nav>
        </header>

        <!-- Hero -->
        <section class="relative z-10 mx-auto max-w-6xl px-6 pt-12 pb-20 lg:pt-20 lg:pb-32">
            <div class="grid gap-12 lg:grid-cols-[1.1fr_1fr] lg:items-center">
                <div>
                    <div class="mb-5 inline-flex items-center gap-2 rounded-full border border-indigo-200/50 bg-indigo-50/50 px-3 py-1 text-xs font-medium text-indigo-700 dark:border-indigo-500/20 dark:bg-indigo-500/10 dark:text-indigo-300">
                        <Sparkles class="size-3.5" />
                        Laravel 13 · Vue 3 · K3s · 1C1G 友善
                    </div>
                    <h1 class="text-4xl leading-tight font-bold tracking-tight sm:text-5xl lg:text-6xl">
                        在 Kubernetes 叢集上
                        <br />
                        <span class="bg-linear-to-r from-indigo-500 via-purple-500 to-pink-500 bg-clip-text text-transparent">看見 π 的誕生</span>
                    </h1>
                    <p class="mt-6 max-w-xl text-base text-neutral-600 sm:text-lg dark:text-neutral-400">
                        透過蒙地卡羅演算法估算 π，把 HPA 自動擴展、Pod 分散計算與即時視覺化等雲原生概念實際展示出來——
                        所有功能都能在一台 1 vCPU、1 GB 記憶體的小型 VPS 上跑起來。
                    </p>

                    <div class="mt-8 flex flex-wrap items-center gap-4">
                        <Link
                            :href="calculate()"
                            class="group inline-flex items-center gap-2 rounded-lg bg-linear-to-r from-indigo-500 to-purple-500 px-6 py-3 font-medium text-white shadow-lg shadow-indigo-500/25 transition-all hover:from-indigo-600 hover:to-purple-600 hover:shadow-indigo-500/40"
                        >
                            <Zap class="size-4 transition-transform group-hover:scale-110" />
                            立即體驗計算
                            <span class="transition-transform group-hover:translate-x-1">→</span>
                        </Link>
                        <a
                            href="https://github.com/chang180/pi-k3s"
                            target="_blank"
                            rel="noopener noreferrer"
                            class="inline-flex items-center gap-2 rounded-lg border border-neutral-200 px-6 py-3 font-medium transition-colors hover:bg-neutral-100 dark:border-neutral-800 dark:hover:bg-neutral-900"
                        >
                            <Github class="size-4" />
                            原始碼
                        </a>
                    </div>
                </div>

                <!-- Hero illustration: pi circle visualization -->
                <div class="relative">
                    <div class="absolute inset-0 -z-10 rounded-3xl bg-linear-to-br from-indigo-500/10 via-purple-500/10 to-pink-500/10 blur-3xl" />
                    <div class="relative aspect-square overflow-hidden rounded-2xl border border-neutral-200/70 bg-white/50 p-8 backdrop-blur-sm dark:border-neutral-800/70 dark:bg-neutral-900/50">
                        <svg viewBox="0 0 200 200" class="size-full">
                            <!-- Square outline -->
                            <rect x="10" y="10" width="180" height="180" fill="none" stroke="currentColor" stroke-width="0.5" class="text-neutral-300 dark:text-neutral-700" />
                            <!-- Quarter circle filled -->
                            <path d="M 10 10 L 190 10 A 180 180 0 0 1 10 190 Z" fill="rgba(99,102,241,0.08)" stroke="rgba(99,102,241,0.6)" stroke-width="1" />
                            <!-- Random dots inside circle (blue) -->
                            <g fill="rgb(99,102,241)" opacity="0.85">
                                <circle cx="35" cy="50" r="2" />
                                <circle cx="60" cy="40" r="2" />
                                <circle cx="85" cy="65" r="2" />
                                <circle cx="120" cy="55" r="2" />
                                <circle cx="50" cy="100" r="2" />
                                <circle cx="80" cy="120" r="2" />
                                <circle cx="100" cy="90" r="2" />
                                <circle cx="40" cy="150" r="2" />
                                <circle cx="65" cy="170" r="2" />
                                <circle cx="140" cy="80" r="2" />
                                <circle cx="155" cy="40" r="2" />
                                <circle cx="25" cy="80" r="2" />
                                <circle cx="115" cy="120" r="2" />
                                <circle cx="20" cy="120" r="2" />
                            </g>
                            <!-- Random dots outside circle (red) -->
                            <g fill="rgb(248,113,113)" opacity="0.85">
                                <circle cx="170" cy="155" r="2" />
                                <circle cx="180" cy="170" r="2" />
                                <circle cx="155" cy="175" r="2" />
                                <circle cx="170" cy="120" r="2" />
                                <circle cx="180" cy="100" r="2" />
                            </g>
                            <!-- π label -->
                            <text x="100" y="115" text-anchor="middle" class="fill-indigo-600 text-5xl font-bold dark:fill-indigo-400" font-size="40">π</text>
                        </svg>
                        <div class="absolute right-4 bottom-4 rounded-md bg-white/80 px-3 py-1.5 text-xs font-mono text-neutral-700 backdrop-blur-sm dark:bg-neutral-900/80 dark:text-neutral-300">
                            π ≈ 4 × (內 / 總)
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <!-- Features -->
        <section class="relative z-10 mx-auto max-w-6xl px-6 pb-20">
            <div class="mb-10 text-center">
                <h2 class="text-3xl font-bold tracking-tight sm:text-4xl">為什麼需要這個專案</h2>
                <p class="mt-3 text-neutral-600 dark:text-neutral-400">把抽象的雲原生概念，轉成你能看到的點與曲線</p>
            </div>
            <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
                <div
                    v-for="feature in features"
                    :key="feature.title"
                    class="group relative overflow-hidden rounded-2xl border border-neutral-200/70 bg-white/50 p-6 backdrop-blur-sm transition-all hover:border-indigo-300 hover:shadow-lg hover:shadow-indigo-500/10 dark:border-neutral-800/70 dark:bg-neutral-900/50 dark:hover:border-indigo-700"
                >
                    <div class="mb-4 inline-flex size-11 items-center justify-center rounded-lg bg-linear-to-br from-indigo-500 to-purple-500 text-white shadow-md">
                        <component :is="feature.icon" class="size-5" />
                    </div>
                    <h3 class="mb-2 text-lg font-semibold">{{ feature.title }}</h3>
                    <p class="text-sm leading-relaxed text-neutral-600 dark:text-neutral-400">{{ feature.description }}</p>
                </div>
            </div>
        </section>

        <!-- How it works -->
        <section class="relative z-10 mx-auto max-w-6xl px-6 pb-20">
            <div class="rounded-2xl border border-neutral-200/70 bg-white/50 p-8 backdrop-blur-sm sm:p-12 dark:border-neutral-800/70 dark:bg-neutral-900/50">
                <div class="mb-10 max-w-2xl">
                    <h2 class="text-3xl font-bold tracking-tight">執行原理</h2>
                    <p class="mt-3 text-neutral-600 dark:text-neutral-400">蒙地卡羅法不需要複雜公式，只要重複實驗夠多次，比例就會逼近 π / 4。</p>
                </div>
                <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
                    <div
                        v-for="step in steps"
                        :key="step.num"
                        class="relative"
                    >
                        <div class="mb-3 font-mono text-2xl font-bold text-indigo-500/40 dark:text-indigo-400/40">{{ step.num }}</div>
                        <h3 class="mb-1.5 font-semibold">{{ step.title }}</h3>
                        <p class="text-sm text-neutral-600 dark:text-neutral-400">{{ step.desc }}</p>
                    </div>
                </div>
            </div>
        </section>

        <!-- Tech stack & CTA -->
        <section class="relative z-10 mx-auto max-w-6xl px-6 pb-24">
            <div class="grid gap-6 lg:grid-cols-2 lg:gap-10">
                <div>
                    <h2 class="text-2xl font-bold tracking-tight">技術棧</h2>
                    <p class="mt-2 text-sm text-neutral-600 dark:text-neutral-400">每個元件都選擇相對輕量的方案，全部加總仍能在 1C1G 環境流暢運作。</p>
                    <div class="mt-5 flex flex-wrap gap-2">
                        <span v-for="tag in ['Laravel 13', 'PHP 8.4', 'Vue 3', 'Inertia v3', 'Tailwind v4', 'K3s', 'SQLite', 'Chart.js']" :key="tag" class="rounded-full border border-neutral-200 bg-white px-3 py-1 text-xs font-medium dark:border-neutral-800 dark:bg-neutral-900">
                            {{ tag }}
                        </span>
                    </div>
                </div>
                <div class="rounded-2xl border border-indigo-200/70 bg-linear-to-br from-indigo-50 to-purple-50 p-8 dark:border-indigo-500/20 dark:from-indigo-950/40 dark:to-purple-950/40">
                    <div class="flex items-start gap-4">
                        <div class="grid size-10 shrink-0 place-items-center rounded-lg bg-white shadow dark:bg-neutral-900">
                            <Activity class="size-5 text-indigo-500" />
                        </div>
                        <div class="flex-1">
                            <h3 class="font-semibold">準備好了嗎？</h3>
                            <p class="mt-1 text-sm text-neutral-600 dark:text-neutral-400">直接進入 Demo，無需註冊；登入後可保留歷史紀錄與 AI 助手對話。</p>
                            <Link
                                :href="calculate()"
                                class="mt-4 inline-flex items-center gap-1.5 text-sm font-medium text-indigo-600 transition-colors hover:text-indigo-700 dark:text-indigo-400 dark:hover:text-indigo-300"
                            >
                                <Box class="size-4" />
                                開始計算 π
                                <span>→</span>
                            </Link>
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <!-- Footer -->
        <footer class="relative z-10 border-t border-neutral-200/70 dark:border-neutral-800/70">
            <div class="mx-auto flex max-w-6xl flex-col items-center justify-between gap-3 px-6 py-6 text-xs text-neutral-500 sm:flex-row dark:text-neutral-500">
                <p>Pi-K3s — 把雲原生變成看得見的東西</p>
                <a
                    href="https://github.com/chang180/pi-k3s"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="inline-flex items-center gap-1.5 transition-colors hover:text-neutral-900 dark:hover:text-neutral-100"
                >
                    <Github class="size-3.5" />
                    chang180/pi-k3s
                </a>
            </div>
        </footer>
    </div>
</template>
