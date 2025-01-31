<script setup>
import { ref, computed } from 'vue';
import { findLorasByName } from '../utils/globalVar';

const props = defineProps({
    show: Boolean
});

const emit = defineEmits(['close', 'created']);

const name = ref('');
const searchQuery = ref('');
const selectedLoras = ref([]);
const positivePrompt = ref('');
const negativePrompt = ref('');
const note = ref('');
const searchResults = ref([]);

const searchResultsComputed = computed(() => {
    if (!searchQuery.value) return [];
    return findLorasByName(searchQuery.value);
});

function handleLoraSelect(lora) {
    const weight = lora.config?.preferred_weight || 1;
    selectedLoras.value.push({
        ...lora,
        weight,
        activation_text: lora.config?.activation_text || ''
    });
    
    // 添加激活词到正面提示词
    if (lora.config?.activation_text) {
        positivePrompt.value = positivePrompt.value
            ? `${positivePrompt.value}, ${lora.config.activation_text}`
            : lora.config.activation_text;
    }
}

async function handleSubmit() {
    if (!name.value.trim()) {
        alert('请输入组合名称');
        return;
    }

    const combination = {
        name: name.value.trim(),
        loras: selectedLoras.value,
        positive_prompt: positivePrompt.value,
        negative_prompt: negativePrompt.value,
        note: note.value
    };

    try {
        const response = await fetch('http://localhost:5000/lora-combinations', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(combination)
        });

        if (!response.ok) throw new Error('保存失败');
        const result = await response.json();
        emit('created', result);
    } catch (error) {
        console.error('Error creating combination:', error);
        alert('保存失败');
    }
}

function handleSearch() {
    console.log("Searching for:", searchQuery.value);
    if (!searchQuery.value.trim()) return;
    
    const results = findLorasByName(searchQuery.value);
    searchResults.value = results;
}

function handleClose() {
    emit('close');
}
</script>

<template>
    <div v-if="show" class="overlay" @click="handleClose">
        <div class="panel" @click.stop>
            <h2>新建 Lora 组合</h2>
            
            <div class="form">
                <div class="form-group">
                    <label>组合名称</label>
                    <input v-model="name" type="text" placeholder="输入组合名称">
                </div>

                <div class="form-group">
                    <label>搜索 Lora</label>
                    <div class="search-box">
                        <input v-model="searchQuery" 
                               type="text" 
                               placeholder="输入关键词搜索..."
                               @keyup.enter="handleSearch">
                        <button @click="handleSearch">搜索</button>
                    </div>
                </div>

                <!-- 搜索结果列表 -->
                <div v-if="searchResults.length" class="search-results">
                    <div v-for="lora in searchResults" 
                         :key="lora.name"
                         class="search-result-item"
                         @click="selectedLoras.push(lora)">
                        <div class="result-info">
                            <div class="result-name">{{ lora.name }}</div>
                            <div class="result-meta">
                                <span>{{ lora.metadata?.ss_base_model_version }}</span>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="form-group">
                    <label>已选择的 Lora</label>
                    <div class="selected-loras">
                        <div v-for="lora in selectedLoras" 
                             :key="lora.name" 
                             class="selected-lora">
                            {{ lora.name }}
                            <button @click="selectedLoras = selectedLoras.filter(l => l.name !== lora.name)">
                                ×
                            </button>
                        </div>
                    </div>
                </div>

                <div class="form-group">
                    <label>正面提示词</label>
                    <textarea v-model="positivePrompt" rows="3"></textarea>
                </div>

                <div class="form-group">
                    <label>负面提示词</label>
                    <textarea v-model="negativePrompt" rows="3"></textarea>
                </div>

                <div class="form-group">
                    <label>备注</label>
                    <textarea v-model="note" rows="3"></textarea>
                </div>

                <div class="buttons">
                    <button class="cancel" @click="handleClose">取消</button>
                    <button class="submit" @click="handleSubmit">保存</button>
                </div>
            </div>
        </div>
    </div>
</template>

<style scoped>
.overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
}

.panel {
    background: white;
    border-radius: 12px;
    padding: 2rem;
    width: 90%;
    max-width: 600px;
    max-height: 90vh;
    overflow-y: auto;
}

.form {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
}

.form-group {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
}

label {
    font-size: 0.9rem;
    color: #666;
}

input, textarea {
    padding: 0.8rem;
    border: 1px solid #ddd;
    border-radius: 6px;
    font-size: 1rem;
}

.search-box {
    display: flex;
    gap: 1rem;
}

.search-box input {
    flex: 1;
}

.buttons {
    display: flex;
    justify-content: flex-end;
    gap: 1rem;
}

.search-results {
    max-height: 300px;
    overflow-y: auto;
    border: 1px solid #eee;
    border-radius: 8px;
}

.search-result-item {
    padding: 1rem;
    border-bottom: 1px solid #eee;
    cursor: pointer;
}

.search-result-item:hover {
    background: #f5f5f5;
}

.selected-loras {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
}

.selected-lora {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem;
    background: #e3f2fd;
    border-radius: 4px;
    font-size: 0.9rem;
}

button {
    padding: 0.8rem 1.5rem;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-size: 1rem;
    transition: all 0.3s ease;
}

.submit {
    background: #4caf50;
    color: white;
}

.cancel {
    background: #f5f5f5;
    color: #666;
}

button:hover {
    opacity: 0.9;
    transform: translateY(-1px);
}
</style>
