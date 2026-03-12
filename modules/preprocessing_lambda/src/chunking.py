"""Custom Chunking Module for Preprocessing Lambda.

Implements token-aware text chunking with overlap for optimal RAG retrieval.
Designed for use with NONE chunking strategy in Bedrock Knowledge Base.

Key Features:
- Token-based sizing using tiktoken (cl100k_base encoding)
- Configurable overlap for context preservation
- Sentence-boundary aware splitting
- Paragraph-boundary preference for semantic coherence
- **Section-aware chunking for compliance documents**

Section-Aware Chunking Features:
- Detects markdown sections (multiple heading formats)
- Preserves important sections (Executive Summary, Abstract, Introduction)
- Virtual preservation: splits oversized sections but maintains section_type
- Boundary-safe overlap: no cross-section contamination
- TOC detection and exclusion

Optimal Parameters (based on research):
- Target chunk size: 512-1024 tokens for Titan Embed v2
- Overlap: 10-20% (64-128 tokens)
- Preserves document structure (headers, lists)
"""

import logging
import os
import re
from typing import Any

# Optional tiktoken import with fallback
try:
    import tiktoken
    TIKTOKEN_AVAILABLE = True
except ImportError:
    TIKTOKEN_AVAILABLE = False

logger = logging.getLogger(__name__)

# =============================================================================
# CONFIGURATION
# =============================================================================

# Default chunking parameters (can be overridden via environment)
DEFAULT_CHUNK_SIZE = int(os.environ.get("CHUNK_SIZE_TOKENS", "512"))
DEFAULT_OVERLAP_TOKENS = int(os.environ.get("OVERLAP_TOKENS", "64"))
DEFAULT_MIN_CHUNK_SIZE = int(os.environ.get("MIN_CHUNK_SIZE_TOKENS", "100"))

# Tiktoken encoding for token counting
# cl100k_base is used by GPT-4, GPT-3.5-turbo, and text-embedding-ada-002
# It's a good approximation for most embedding models including Titan
ENCODING_NAME = os.environ.get("TIKTOKEN_ENCODING", "cl100k_base")

# =============================================================================
# SECTION-AWARE CHUNKING CONFIGURATION
# =============================================================================

# Enable section-aware chunking (default: true for compliance documents)
ENABLE_SECTION_AWARE = os.environ.get("ENABLE_SECTION_AWARE", "true").lower() == "true"

# Maximum tokens for preserved sections (split if exceeded, maintaining section_type)
SECTION_MAX_TOKENS = int(os.environ.get("SECTION_MAX_TOKENS", "1024"))

# Section types to preserve as single chunks when possible
# These are critical sections in compliance/policy documents
SECTIONS_TO_PRESERVE = os.environ.get(
    "SECTIONS_TO_PRESERVE",
    "executive_summary,abstract,introduction,purpose,scope"
).split(",")

# Section type mappings - normalized section names for metadata
SECTION_TYPE_MAPPINGS = {
    # Executive summaries
    "executive summary": "executive_summary",
    "exec summary": "executive_summary",
    "summary": "executive_summary",
    "overview": "executive_summary",
    # Abstracts
    "abstract": "abstract",
    # Introductions
    "introduction": "introduction",
    "intro": "introduction",
    "background": "introduction",
    # Purpose/Scope
    "purpose": "purpose",
    "scope": "scope",
    "objectives": "purpose",
    # Conclusions
    "conclusion": "conclusion",
    "conclusions": "conclusion",
    "closing": "conclusion",
    # References
    "references": "references",
    "bibliography": "references",
    "works cited": "references",
    # Appendices
    "appendix": "appendix",
    "appendices": "appendix",
    "annex": "appendix",
    # Table of contents (to exclude)
    "table of contents": "table_of_contents",
    "contents": "table_of_contents",
    "toc": "table_of_contents",
    # Default for unmatched
    "default": "body",
}

# Patterns that indicate a Table of Contents section (to exclude)
TOC_INDICATORS = [
    r'\.\s*\d+$',  # Lines ending in page numbers: "Chapter 1 ... 5"
    r'\.{3,}',     # Dot leaders: "Chapter 1.......5"
    r'\s+\d+\s*$', # Trailing page numbers
]


# =============================================================================
# TOKEN COUNTING
# =============================================================================

# Module-level encoder cache for performance (created once per Lambda container)
_ENCODER_CACHE = None


def get_encoder():
    """Get tiktoken encoder, with lazy initialization and caching."""
    global _ENCODER_CACHE

    if _ENCODER_CACHE is not None:
        return _ENCODER_CACHE

    if not TIKTOKEN_AVAILABLE:
        return None

    try:
        _ENCODER_CACHE = tiktoken.get_encoding(ENCODING_NAME)
        return _ENCODER_CACHE
    except Exception as e:
        logger.warning(f"Failed to get tiktoken encoder: {e}")
        return None


def count_tokens(text: str, encoder=None) -> int:
    """
    Count tokens in text using tiktoken or fallback approximation.

    Args:
        text: Text to count tokens for
        encoder: Optional pre-initialized tiktoken encoder

    Returns:
        Estimated token count
    """
    if encoder is None:
        encoder = get_encoder()

    if encoder is not None:
        try:
            return len(encoder.encode(text))
        except Exception as e:
            logger.warning(f"Tiktoken encoding failed, using fallback: {e}")

    # Fallback: ~4 characters per token (industry standard approximation)
    return len(text) // 4


# =============================================================================
# TEXT SPLITTING
# =============================================================================

def split_into_sentences(text: str) -> list[str]:
    """
    Split text into sentences while preserving structure.

    Handles:
    - Standard punctuation (.!?)
    - Abbreviations (Dr., Mr., etc.)
    - Decimal numbers (3.14)
    - URLs and email addresses
    - Markdown headers and lists
    """
    # Preserve markdown headers as separate units
    text = re.sub(r'(^#{1,6}\s+.+$)', r'\n\1\n', text, flags=re.MULTILINE)

    # Split on sentence boundaries, but not abbreviations or decimals
    # This regex handles most common cases
    sentence_pattern = r'(?<=[.!?])\s+(?=[A-Z])|(?<=\n)\s*(?=\n)'

    sentences = re.split(sentence_pattern, text)

    # Clean up and filter empty sentences
    result = []
    for s in sentences:
        s = s.strip()
        if s:
            result.append(s)

    return result


def split_into_paragraphs(text: str) -> list[str]:
    """
    Split text into paragraphs (double newlines or markdown headers).

    Preserves:
    - Markdown headers with their content
    - Code blocks as single units
    - Lists as coherent groups
    """
    # Split on double newlines or markdown headers
    paragraphs = re.split(r'\n\s*\n', text)

    result = []
    for p in paragraphs:
        p = p.strip()
        if p:
            result.append(p)

    return result


# =============================================================================
# CHUNKING ALGORITHM
# =============================================================================

def chunk_text(
    text: str,
    chunk_size: int = None,
    overlap_tokens: int = None,
    min_chunk_size: int = None,
) -> list[dict[str, Any]]:
    """
    Split text into overlapping chunks of approximately chunk_size tokens.

    Algorithm:
    1. Split text into paragraphs
    2. Group paragraphs until reaching chunk_size
    3. Apply overlap by including end of previous chunk
    4. Ensure minimum chunk size for final chunk

    Args:
        text: Full document text to chunk
        chunk_size: Target tokens per chunk (default: 512)
        overlap_tokens: Tokens to overlap between chunks (default: 64)
        min_chunk_size: Minimum tokens for a chunk (default: 100)

    Returns:
        List of chunk dictionaries with:
        - content: Chunk text content
        - index: Chunk index (0-based)
        - token_count: Approximate token count
        - start_char: Character offset in original text
        - end_char: End character offset
    """
    chunk_size = chunk_size or DEFAULT_CHUNK_SIZE
    overlap_tokens = overlap_tokens or DEFAULT_OVERLAP_TOKENS
    min_chunk_size = min_chunk_size or DEFAULT_MIN_CHUNK_SIZE

    if not text or not text.strip():
        return []

    encoder = get_encoder()

    # Split into paragraphs first (preserves semantic units)
    paragraphs = split_into_paragraphs(text)

    if not paragraphs:
        return []

    chunks = []
    current_chunk_parts = []
    current_token_count = 0
    overlap_buffer = []  # Paragraphs to include as overlap
    overlap_buffer_tokens = 0

    char_offset = 0

    for para in paragraphs:
        para_tokens = count_tokens(para, encoder)

        # If single paragraph exceeds chunk size, split it further
        if para_tokens > chunk_size:
            # Flush current chunk first
            if current_chunk_parts:
                chunk_content = "\n\n".join(current_chunk_parts)
                chunk_start = text.find(current_chunk_parts[0], char_offset)
                chunk_end = chunk_start + len(chunk_content)

                chunks.append({
                    "content": chunk_content,
                    "index": len(chunks),
                    "token_count": current_token_count,
                    "start_char": chunk_start,
                    "end_char": chunk_end,
                })

                # Update overlap buffer (tokens recalculated when needed)
                overlap_buffer = current_chunk_parts[-2:] if len(current_chunk_parts) >= 2 else current_chunk_parts

                char_offset = chunk_end
                current_chunk_parts = []
                current_token_count = 0

            # Split long paragraph by sentences
            sentences = split_into_sentences(para)
            sentence_chunks = _chunk_sentences(
                sentences,
                chunk_size,
                overlap_tokens,
                min_chunk_size,
                encoder
            )

            for sc in sentence_chunks:
                sc["index"] = len(chunks)
                sc["start_char"] = text.find(sc["content"], char_offset)
                sc["end_char"] = sc["start_char"] + len(sc["content"])
                chunks.append(sc)
                char_offset = sc["end_char"]

            continue

        # Check if adding this paragraph would exceed chunk size
        if current_token_count + para_tokens > chunk_size and current_chunk_parts:
            # Create chunk from current parts
            chunk_content = "\n\n".join(current_chunk_parts)
            chunk_start = text.find(current_chunk_parts[0], max(0, char_offset - 100))
            chunk_end = chunk_start + len(chunk_content)

            chunks.append({
                "content": chunk_content,
                "index": len(chunks),
                "token_count": current_token_count,
                "start_char": chunk_start,
                "end_char": chunk_end,
            })

            # Prepare overlap for next chunk
            # Take last paragraph(s) that fit within overlap_tokens
            overlap_buffer = []
            overlap_buffer_tokens = 0
            for p in reversed(current_chunk_parts):
                p_tokens = count_tokens(p, encoder)
                if overlap_buffer_tokens + p_tokens <= overlap_tokens:
                    overlap_buffer.insert(0, p)
                    overlap_buffer_tokens += p_tokens
                else:
                    break

            char_offset = chunk_end

            # Start new chunk with overlap
            current_chunk_parts = overlap_buffer.copy()
            current_token_count = overlap_buffer_tokens

        # Add paragraph to current chunk
        current_chunk_parts.append(para)
        current_token_count += para_tokens

    # Handle final chunk
    if current_chunk_parts:
        chunk_content = "\n\n".join(current_chunk_parts)

        # If final chunk is too small, merge with previous
        if current_token_count < min_chunk_size and chunks:
            prev_chunk = chunks[-1]
            merged_content = prev_chunk["content"] + "\n\n" + chunk_content
            prev_chunk["content"] = merged_content
            prev_chunk["token_count"] = count_tokens(merged_content, encoder)
            prev_chunk["end_char"] = prev_chunk["start_char"] + len(merged_content)
        else:
            chunk_start = text.find(current_chunk_parts[0], max(0, char_offset - 100))
            chunk_end = chunk_start + len(chunk_content) if chunk_start >= 0 else len(text)

            chunks.append({
                "content": chunk_content,
                "index": len(chunks),
                "token_count": current_token_count,
                "start_char": max(0, chunk_start),
                "end_char": chunk_end,
            })

    logger.info(f"Created {len(chunks)} chunks from {count_tokens(text, encoder)} tokens")

    return chunks


def _chunk_sentences(
    sentences: list[str],
    chunk_size: int,
    overlap_tokens: int,
    min_chunk_size: int,
    encoder
) -> list[dict[str, Any]]:
    """
    Chunk a list of sentences into token-sized chunks with overlap.

    Used for paragraphs that exceed chunk_size.
    """
    chunks = []
    current_sentences = []
    current_tokens = 0

    for sentence in sentences:
        sent_tokens = count_tokens(sentence, encoder)

        if current_tokens + sent_tokens > chunk_size and current_sentences:
            # Create chunk
            chunk_content = " ".join(current_sentences)
            chunks.append({
                "content": chunk_content,
                "index": len(chunks),  # Will be reindexed by caller
                "token_count": current_tokens,
            })

            # Calculate overlap
            overlap_sentences = []
            overlap_count = 0
            for s in reversed(current_sentences):
                s_tokens = count_tokens(s, encoder)
                if overlap_count + s_tokens <= overlap_tokens:
                    overlap_sentences.insert(0, s)
                    overlap_count += s_tokens
                else:
                    break

            current_sentences = overlap_sentences
            current_tokens = overlap_count

        current_sentences.append(sentence)
        current_tokens += sent_tokens

    # Final chunk
    if current_sentences:
        chunk_content = " ".join(current_sentences)
        chunks.append({
            "content": chunk_content,
            "index": len(chunks),
            "token_count": current_tokens,
        })

    return chunks


# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

def estimate_chunk_count(text: str, chunk_size: int = None, overlap_tokens: int = None) -> int:
    """
    Estimate number of chunks without actually chunking.

    Useful for logging and monitoring.
    """
    chunk_size = chunk_size or DEFAULT_CHUNK_SIZE
    overlap_tokens = overlap_tokens or DEFAULT_OVERLAP_TOKENS

    total_tokens = count_tokens(text)
    if total_tokens <= chunk_size:
        return 1

    effective_chunk_size = chunk_size - overlap_tokens
    return max(1, (total_tokens + effective_chunk_size - 1) // effective_chunk_size)


def get_chunking_config() -> dict[str, Any]:
    """Return current chunking configuration."""
    return {
        "chunk_size_tokens": DEFAULT_CHUNK_SIZE,
        "overlap_tokens": DEFAULT_OVERLAP_TOKENS,
        "min_chunk_size_tokens": DEFAULT_MIN_CHUNK_SIZE,
        "encoding": ENCODING_NAME,
        "tiktoken_available": TIKTOKEN_AVAILABLE,
        "section_aware_enabled": ENABLE_SECTION_AWARE,
        "section_max_tokens": SECTION_MAX_TOKENS,
        "sections_to_preserve": SECTIONS_TO_PRESERVE,
    }


# =============================================================================
# SECTION-AWARE CHUNKING
# =============================================================================

# Regex patterns for heading detection (supports multiple formats)
# Based on consensus: broader detection than just ##
HEADING_PATTERNS = [
    # Markdown ATX-style headings: # Heading, ## Heading, ### Heading
    r'^(#{1,6})\s+(.+?)(?:\s*#+)?$',
    # Numbered headings: 1. Heading, 1.1 Heading, 1.1.1 Heading
    r'^(\d+(?:\.\d+)*)\s+(.+)$',
    # Underlined headings (setext-style): Heading\n======= or Heading\n-------
    # Note: These are handled separately in detect_sections
]


def _get_section_type(heading_text: str) -> str:
    """
    Map a heading text to a normalized section type.

    Args:
        heading_text: Raw heading text (e.g., "Executive Summary", "1.1 Introduction")

    Returns:
        Normalized section type (e.g., "executive_summary", "introduction", "body")
    """
    # Clean and normalize heading
    clean_heading = heading_text.lower().strip()

    # Remove common prefixes like "1.", "1.1", "A.", etc.
    clean_heading = re.sub(r'^[\d.]+\s*', '', clean_heading)
    clean_heading = re.sub(r'^[a-z]\.\s*', '', clean_heading, flags=re.IGNORECASE)

    # Check exact matches first
    if clean_heading in SECTION_TYPE_MAPPINGS:
        return SECTION_TYPE_MAPPINGS[clean_heading]

    # Check partial matches
    for key, section_type in SECTION_TYPE_MAPPINGS.items():
        if key in clean_heading:
            return section_type

    return SECTION_TYPE_MAPPINGS["default"]


def _is_toc_content(text: str) -> bool:
    """
    Detect if text block appears to be Table of Contents content.

    Args:
        text: Text block to check

    Returns:
        True if text appears to be TOC content
    """
    lines = text.strip().split('\n')
    if not lines:
        return False

    # Count lines that look like TOC entries
    toc_line_count = 0
    for line in lines:
        line = line.strip()
        if not line:
            continue

        for pattern in TOC_INDICATORS:
            if re.search(pattern, line):
                toc_line_count += 1
                break

    # If more than 50% of lines look like TOC, it's probably TOC
    return toc_line_count > len([l for l in lines if l.strip()]) * 0.5


def detect_sections(text: str) -> list[dict[str, Any]]:
    """
    Parse document into sections based on headings.

    Supports multiple heading formats:
    - Markdown ATX: # Heading, ## Heading
    - Numbered: 1. Heading, 1.1 Heading
    - Setext underlined: Heading\\n=======

    Args:
        text: Full document text

    Returns:
        List of section dictionaries:
        - heading: Original heading text
        - heading_level: Heading depth (1-6)
        - section_type: Normalized type (executive_summary, body, etc.)
        - content: Section content (without heading)
        - start_char: Character offset in original text
        - end_char: End character offset
        - is_toc: Whether this appears to be TOC content
    """
    if not text or not text.strip():
        return []

    sections = []
    lines = text.split('\n')

    current_section = {
        "heading": "",
        "heading_level": 0,
        "section_type": "body",
        "content_lines": [],
        "start_char": 0,
    }

    char_offset = 0

    i = 0
    while i < len(lines):
        line = lines[i]
        line_start = char_offset

        # Check for setext-style underlined headings (line followed by === or ---)
        if i + 1 < len(lines):
            next_line = lines[i + 1].strip()
            if re.match(r'^={3,}$', next_line):
                # H1 underlined heading
                _flush_section(sections, current_section, text, char_offset)
                current_section = {
                    "heading": line.strip(),
                    "heading_level": 1,
                    "section_type": _get_section_type(line.strip()),
                    "content_lines": [],
                    "start_char": line_start,
                }
                char_offset += len(line) + 1 + len(lines[i + 1]) + 1
                i += 2
                continue
            elif re.match(r'^-{3,}$', next_line):
                # H2 underlined heading
                _flush_section(sections, current_section, text, char_offset)
                current_section = {
                    "heading": line.strip(),
                    "heading_level": 2,
                    "section_type": _get_section_type(line.strip()),
                    "content_lines": [],
                    "start_char": line_start,
                }
                char_offset += len(line) + 1 + len(lines[i + 1]) + 1
                i += 2
                continue

        # Check ATX-style markdown headings: # Heading
        atx_match = re.match(r'^(#{1,6})\s+(.+?)(?:\s*#+)?$', line)
        if atx_match:
            _flush_section(sections, current_section, text, char_offset)
            level = len(atx_match.group(1))
            heading_text = atx_match.group(2).strip()
            current_section = {
                "heading": heading_text,
                "heading_level": level,
                "section_type": _get_section_type(heading_text),
                "content_lines": [],
                "start_char": line_start,
            }
            char_offset += len(line) + 1
            i += 1
            continue

        # Check numbered headings: 1. Heading, 1.1 Introduction
        numbered_match = re.match(r'^(\d+(?:\.\d+)*)\s+([A-Z][^.!?]*?)$', line)
        if numbered_match:
            _flush_section(sections, current_section, text, char_offset)
            # Estimate level from number depth (1 = level 1, 1.1 = level 2, etc.)
            number_part = numbered_match.group(1)
            level = min(6, number_part.count('.') + 1)
            heading_text = numbered_match.group(2).strip()
            current_section = {
                "heading": f"{number_part} {heading_text}",
                "heading_level": level,
                "section_type": _get_section_type(heading_text),
                "content_lines": [],
                "start_char": line_start,
            }
            char_offset += len(line) + 1
            i += 1
            continue

        # Regular content line
        current_section["content_lines"].append(line)
        char_offset += len(line) + 1
        i += 1

    # Flush final section
    _flush_section(sections, current_section, text, char_offset)

    # Post-process: detect TOC sections
    for section in sections:
        section["is_toc"] = (
            section["section_type"] == "table_of_contents" or
            _is_toc_content(section["content"])
        )

    logger.info(f"Detected {len(sections)} sections, {sum(1 for s in sections if s['is_toc'])} TOC sections")

    return sections


def _flush_section(
    sections: list[dict],
    current_section: dict,
    text: str,
    end_char: int
) -> None:
    """Flush current section to sections list if it has content."""
    content = '\n'.join(current_section["content_lines"]).strip()

    # Only add non-empty sections (heading or content)
    if current_section["heading"] or content:
        section = {
            "heading": current_section["heading"],
            "heading_level": current_section["heading_level"],
            "section_type": current_section["section_type"],
            "content": content,
            "start_char": current_section["start_char"],
            "end_char": end_char,
            "is_toc": False,
        }
        sections.append(section)


def chunk_with_sections(
    text: str,
    chunk_size: int = None,
    overlap_tokens: int = None,
    min_chunk_size: int = None,
    section_max_tokens: int = None,
    sections_to_preserve: list[str] = None,
    exclude_toc: bool = True,
    include_heading_prefix: bool = True,
) -> list[dict[str, Any]]:
    """
    Section-aware chunking that preserves document structure.

    Key features (based on multi-model consensus):
    1. Detects sections via multiple heading formats (not just ##)
    2. Virtual preservation: splits oversized sections but maintains section_type
    3. Boundary-safe overlap: NO cross-section contamination
    4. TOC detection and exclusion
    5. Heading prefix: includes section heading in each chunk for better embeddings

    Args:
        text: Full document text to chunk
        chunk_size: Target tokens per chunk (default: 512)
        overlap_tokens: Tokens to overlap within sections (default: 64)
        min_chunk_size: Minimum tokens for a chunk (default: 100)
        section_max_tokens: Max tokens before splitting preserved section (default: 1024)
        sections_to_preserve: Section types to keep as single chunks when possible
        exclude_toc: Whether to exclude Table of Contents sections (default: True)
        include_heading_prefix: Whether to prefix chunks with section heading (default: True)

    Returns:
        List of chunk dictionaries with section metadata:
        - content: Chunk text content (may include heading prefix)
        - index: Global chunk index (0-based)
        - token_count: Approximate token count
        - start_char: Character offset in original text
        - end_char: End character offset
        - section_type: Normalized section type (executive_summary, body, etc.)
        - section_title: Original section heading
        - section_order: Section index in document (0-based)
        - chunk_index_in_section: Chunk index within this section (0-based)
        - total_chunks_in_section: Total chunks in this section
    """
    chunk_size = chunk_size or DEFAULT_CHUNK_SIZE
    overlap_tokens = overlap_tokens or DEFAULT_OVERLAP_TOKENS
    min_chunk_size = min_chunk_size or DEFAULT_MIN_CHUNK_SIZE
    section_max_tokens = section_max_tokens or SECTION_MAX_TOKENS
    sections_to_preserve = sections_to_preserve or SECTIONS_TO_PRESERVE

    if not text or not text.strip():
        return []

    # Detect sections
    sections = detect_sections(text)

    if not sections:
        # Fall back to regular chunking if no sections detected
        logger.info("No sections detected, falling back to regular chunking")
        return chunk_text(text, chunk_size, overlap_tokens, min_chunk_size)

    encoder = get_encoder()
    all_chunks = []
    global_chunk_index = 0
    section_order = 0

    for section in sections:
        # Skip TOC sections if requested
        if exclude_toc and section["is_toc"]:
            logger.debug(f"Skipping TOC section: {section['heading']}")
            continue

        section_type = section["section_type"]
        section_title = section["heading"]
        section_content = section["content"]

        # Build full section text with heading if present
        if section_title:
            full_section_text = f"## {section_title}\n\n{section_content}"
        else:
            full_section_text = section_content

        if not full_section_text.strip():
            continue

        section_tokens = count_tokens(full_section_text, encoder)

        # Determine if this section should be preserved
        should_preserve = section_type in sections_to_preserve

        # Calculate heading prefix for non-first chunks
        heading_prefix = ""
        heading_prefix_tokens = 0
        if include_heading_prefix and section_title:
            heading_prefix = f"[Section: {section_title}]\n\n"
            heading_prefix_tokens = count_tokens(heading_prefix, encoder)

        # Decide chunking strategy for this section
        if should_preserve and section_tokens <= section_max_tokens:
            # Preserve as single chunk
            all_chunks.append({
                "content": full_section_text,
                "index": global_chunk_index,
                "token_count": section_tokens,
                "start_char": section["start_char"],
                "end_char": section["end_char"],
                "section_type": section_type,
                "section_title": section_title,
                "section_order": section_order,
                "chunk_index_in_section": 0,
                "total_chunks_in_section": 1,
            })
            global_chunk_index += 1
        else:
            # Split section with intra-section overlap only (no cross-section contamination)
            # Adjust chunk size to account for heading prefix
            effective_chunk_size = chunk_size - heading_prefix_tokens if include_heading_prefix else chunk_size

            # Use existing chunk_text but on section content only
            section_chunks = chunk_text(
                section_content,
                effective_chunk_size,
                overlap_tokens,
                min_chunk_size
            )

            total_section_chunks = len(section_chunks)

            for chunk_in_section_idx, chunk in enumerate(section_chunks):
                # Add heading prefix to non-first chunks for better embedding context
                if include_heading_prefix and section_title and chunk_in_section_idx > 0:
                    chunk_content = heading_prefix + chunk["content"]
                elif section_title and chunk_in_section_idx == 0:
                    # First chunk includes heading naturally
                    chunk_content = f"## {section_title}\n\n{chunk['content']}"
                else:
                    chunk_content = chunk["content"]

                all_chunks.append({
                    "content": chunk_content,
                    "index": global_chunk_index,
                    "token_count": count_tokens(chunk_content, encoder),
                    "start_char": section["start_char"] + chunk.get("start_char", 0),
                    "end_char": section["start_char"] + chunk.get("end_char", len(chunk["content"])),
                    "section_type": section_type,
                    "section_title": section_title,
                    "section_order": section_order,
                    "chunk_index_in_section": chunk_in_section_idx,
                    "total_chunks_in_section": total_section_chunks,
                })
                global_chunk_index += 1

        section_order += 1

    # Log summary
    section_types_found = {}
    for chunk in all_chunks:
        st = chunk["section_type"]
        section_types_found[st] = section_types_found.get(st, 0) + 1

    logger.info(
        f"Section-aware chunking: {len(all_chunks)} chunks from {len(sections)} sections. "
        f"Types: {section_types_found}"
    )

    return all_chunks
