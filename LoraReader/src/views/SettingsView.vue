<script setup>
import PathSelector from '@/components/PathSelector.vue';

function handlePathConfirm(path) {
    // 处理路径确认
    console.log('New path:', path);
}
</script>

<template>
    <div class="settings-view">
        <h1>设置</h1>
        <div class="settings-section">
            <h2>Lora 文件夹设置</h2>
            <PathSelector @confirm="handlePathConfirm" />
        </div>
    </div>
</template>

<style scoped>
.settings-view {
    padding: 2rem;
    max-width: 800px;
    margin: 0 auto;
}

h1 {
    margin-bottom: 2rem;
    color: #333;
}

.settings-section {
    background: white;
    border-radius: 12px;
    padding: 2rem;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

h2 {
    color: #666;
    margin-bottom: 1rem;
    font-size: 1.2rem;
}
</style>
