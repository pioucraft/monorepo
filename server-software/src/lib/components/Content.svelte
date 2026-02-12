<script lang="ts">
  interface Props {
    content: string;
    onToggleCheckbox: (checkboxIndex: number) => void;
  }

  let { content, onToggleCheckbox }: Props = $props();

  let segments = $derived(parseSegments(content));

  function parseSegments(content: string) {
    const regex = /\[(\s*x?)\]/gi;
    let lastIndex = 0;
    let checkboxIndex = 0;
    const parts: { type: 'text' | 'checkbox'; content: string; checked?: boolean; idx?: number }[] = [];

    let match;
    while ((match = regex.exec(content)) !== null) {
      // Add text before match
      if (match.index > lastIndex) {
        parts.push({ type: 'text', content: content.slice(lastIndex, match.index) });
      }
      // Add checkbox
      const checked = match[1].toLowerCase().includes('x');
      parts.push({ type: 'checkbox', content: match[0], checked, idx: checkboxIndex++ });
      lastIndex = regex.lastIndex;
    }
    // Add remaining text
    if (lastIndex < content.length) {
      parts.push({ type: 'text', content: content.slice(lastIndex) });
    }
    return parts;
  }
</script>

{#each segments as segment}
  {#if segment.type === 'text'}
{@html segment.content.replace(/\n/g, '<br>')}
  {:else}
    <input type="checkbox" checked={segment.checked} onchange={() => onToggleCheckbox(segment.idx!)} />
  {/if}
{/each}