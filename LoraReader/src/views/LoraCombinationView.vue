<script setup>
import { ref, onMounted } from 'vue';
import LoraCombineDetail from '../components/LoraCombineDetail.vue';
import AddLoraPanel from '../components/AddLoraPanel.vue';

const combinations = ref([]);
const showAddPanel = ref(false);
const selectedCombination = ref(null);
const currentEditingId = ref(null);

onMounted(async () => {
    await loadCombinations();
});

async function loadCombinations() {
    try {
        const response = await fetch('http://localhost:5000/lora-combinations');
        if (!response.ok) throw new Error('Failed to load combinations');
        combinations.value = await response.json();
        console.log('Loaded combinations:', combinations.value);
    } catch (error) {
        console.error('Error loading combinations:', error);
    }
}

function handleAddNew() {
    console.log('Opening add panel');
    showAddPanel.value = true;
}

function handleClose() {
    console.log('Closing add panel');
    showAddPanel.value = false;
}

function handleCombinationClick(combination) {
    selectedCombination.value = combination;
}

async function handleCombinationCreated(combination) {
    await loadCombinations();
    showAddPanel.value = false;
}
</script>

<template>
    <div class="combination-view">
        <div class="header">
            <h1>Lora 组合</h1>
            <button class="add-btn" @click="handleAddNew">添加新组合</button>
        </div>

        <!-- 组合列表 -->
        <div class="combinations-grid">
            <div v-for="combo in combinations" 
                 :key="combo.id"
                 class="combo-card"
                 @click="handleCombinationClick(combo)">
                <img v-if="combo.preview_path" 
                     :src="`http://localhost:5000${combo.preview_path}`" 
                     :alt="combo.name">
                <div class="info">
                    <h3>{{ combo.name }}</h3>
                    <div class="lora-count">{{ combo.loras?.length || 0 }} 个 Lora</div>
                </div>
            </div>
        </div>

        <!-- 组件 -->
        <AddLoraPanel
            v-if="showAddPanel"
            :show="true"
            @close="handleClose"
            @created="handleCombinationCreated"
        />
        
        <LoraCombineDetail 
            v-if="selectedCombination"
            :combination="selectedCombination"
            :show="true"
            @close="selectedCombination = null"
        />
    </div>
</template>

<style scoped>
.combination-view {
    padding: 2rem;
    max-width: 1200px;
    margin: 0 auto;
}

.header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 2rem;
}

.add-btn {
    padding: 0.8rem 1.5rem;
    background: #4caf50;
    color: white;
    border: none;
    border-radius: 8px;
    cursor: pointer;
    font-size: 1rem;
    transition: all 0.3s ease;
}

.add-btn:hover {
    background: #388e3c;
    transform: translateY(-2px);
}

.combinations-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
    gap: 1.5rem;
}

.combo-card {
    background: white;
    border-radius: 12px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    overflow: hidden;
    cursor: pointer;
    transition: all 0.3s ease;
}

.combo-card:hover {
    transform: translateY(-4px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.combo-card img {
    width: 100%;
    height: 180px;
    object-fit: cover;
}

.info {
    padding: 1rem;
}

.info h3 {
    margin: 0;
    font-size: 1.1rem;
    color: #333;
}

.lora-count {
    margin-top: 0.5rem;
    font-size: 0.9rem;
    color: #666;
}
</style>
