#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LLM Service for Text Polish and Correction
Supports OpenAI API compatible endpoints (e.g., ModelScope, Ollama, etc.)
Uses OpenAI SDK for reliable API communication
"""

import logging
from typing import Optional, Dict, Tuple
import time

# Try to import OpenAI SDK
try:
    from openai import OpenAI, APIError, APIConnectionError, RateLimitError, AuthenticationError
    OPENAI_SDK_AVAILABLE = True
except ImportError:
    OPENAI_SDK_AVAILABLE = False
    # Fallback to requests if OpenAI SDK is not available
    import requests

logger = logging.getLogger(__name__)


class LLMService:
    """LLM service for text polishing and correction using OpenAI SDK"""

    def __init__(self, config: Dict):
        """
        Initialize LLM service

        Args:
            config: LLM configuration dictionary with keys:
                - enabled: bool, Enable/disable LLM service
                - api_url: str, LLM API base URL (e.g., https://dashscope.aliyuncs.com/compatible-mode/v1)
                - api_key: str, API key for authentication
                - model: str, Model name (e.g., qwen-turbo, gpt-3.5-turbo)
                - timeout: int, Request timeout in seconds
                - max_retries: int, Maximum retry attempts
                - retry_delay: int, Delay between retries in seconds
                - temperature: float, Sampling temperature
                - max_tokens: int, Maximum tokens in response
                - system_prompt: str, System prompt for LLM
        """
        self.enabled = config.get("enabled", False)
        self.api_url = config.get("api_url", "").strip()
        self.api_key = config.get("api_key", "").strip()
        self.model = config.get("model", "")
        self.timeout = config.get("timeout", 30)
        self.max_retries = config.get("max_retries", 2)
        self.retry_delay = config.get("retry_delay", 1)

        # System prompt for polishing and correcting transcription
        self.system_prompt = config.get(
            "system_prompt",
            "You are a helpful assistant. Your task is to polish and correct the transcribed text. "
            "Keep the original meaning and improve grammar, punctuation, and clarity. "
            "Return only the corrected text without any explanation."
        )

        self.temperature = config.get("temperature", 0.3)
        self.max_tokens = config.get("max_tokens", 2000)

        # Initialize OpenAI client if enabled
        self.client = None
        if self.is_enabled() and OPENAI_SDK_AVAILABLE:
            try:
                self.client = OpenAI(
                    api_key=self.api_key,
                    base_url=self.api_url,
                    timeout=self.timeout,
                )
                logger.info(f"LLM Service initialized with OpenAI SDK - Model: {self.model}")
            except Exception as e:
                logger.warning(f"Failed to initialize OpenAI client: {e}")
                self.client = None
        elif self.enabled and not OPENAI_SDK_AVAILABLE:
            logger.warning("OpenAI SDK not available, LLM service will use requests library as fallback")

        logger.info(f"LLM Service initialized - Enabled: {self.enabled}, Model: {self.model}, SDK: {OPENAI_SDK_AVAILABLE}")

    def is_enabled(self) -> bool:
        """Check if LLM service is enabled"""
        return self.enabled and bool(self.api_url) and bool(self.api_key)

    def validate_config(self) -> Tuple[bool, str]:
        """
        Validate LLM configuration

        Returns:
            Tuple of (is_valid, error_message)
        """
        if not self.enabled:
            return True, ""

        if not self.api_url:
            return False, "LLM API URL not configured"

        if not self.api_key:
            return False, "LLM API key not configured"

        if not self.model:
            return False, "LLM model not specified"

        return True, ""

    def health_check(self) -> Tuple[bool, str]:
        """
        Perform health check on LLM API

        Returns:
            Tuple of (is_healthy, status_message)
        """
        if not self.is_enabled():
            return True, "LLM service is disabled"

        if not OPENAI_SDK_AVAILABLE:
            return False, "OpenAI SDK not available"

        try:
            # Try a minimal request to check connectivity
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "user", "content": "test"}
                ],
                max_tokens=10,
            )
            return True, "LLM API is healthy"

        except AuthenticationError as e:
            return False, f"LLM API authentication failed: Invalid API key or base URL"
        except RateLimitError as e:
            return False, f"LLM API rate limited (429): {str(e)}"
        except APIConnectionError as e:
            return False, f"LLM API connection error: {str(e)}"
        except APIError as e:
            return False, f"LLM API error: {str(e)}"
        except Exception as e:
            return False, f"LLM health check failed: {str(e)}"

    def polish_text(self, text: str) -> Tuple[Optional[str], bool, str]:
        """
        Polish and correct transcribed text using LLM

        Args:
            text: Original transcribed text

        Returns:
            Tuple of (corrected_text, success, error_message)
            - If success=True, corrected_text contains the polished text
            - If success=False, corrected_text=None and error_message explains the failure
        """
        if not self.is_enabled():
            logger.debug("LLM service is disabled, returning original text")
            return text, True, ""

        if not text or not text.strip():
            logger.debug("Empty text provided, skipping LLM polishing")
            return text, True, ""

        if not OPENAI_SDK_AVAILABLE:
            logger.warning("OpenAI SDK not available, skipping LLM polishing")
            return None, False, "OpenAI SDK not available"

        logger.info(f"Starting LLM text polishing (length: {len(text)})")

        for attempt in range(self.max_retries):
            try:
                logger.debug(f"Sending request to LLM API (attempt {attempt + 1}/{self.max_retries})")

                # Use OpenAI SDK to call LLM
                response = self.client.chat.completions.create(
                    model=self.model,
                    messages=[
                        {
                            "role": "system",
                            "content": self.system_prompt,
                        },
                        {
                            "role": "user",
                            "content": f"Please polish and correct this text:\n\n{text}",
                        },
                    ],
                    temperature=self.temperature,
                    max_tokens=self.max_tokens,
                )

                # Extract content from response
                if not response.choices:
                    error_msg = "LLM API response missing choices"
                    logger.error(f"{error_msg}")
                    return None, False, error_msg

                corrected_text = response.choices[0].message.content.strip()

                if not corrected_text:
                    error_msg = "LLM API returned empty response"
                    logger.warning(error_msg)
                    return None, False, error_msg

                logger.info(f"LLM polishing completed successfully (length: {len(corrected_text)})")
                return corrected_text, True, ""

            except AuthenticationError as e:
                error_msg = "LLM API authentication failed: Invalid API key or base URL"
                logger.error(error_msg)
                return None, False, error_msg

            except RateLimitError as e:
                error_msg = "LLM API rate limit exceeded (429)"
                logger.warning(f"{error_msg}, attempt {attempt + 1}/{self.max_retries}")
                if attempt < self.max_retries - 1:
                    wait_time = self.retry_delay * (2 ** attempt)  # Exponential backoff
                    logger.info(f"Waiting {wait_time} seconds before retry...")
                    time.sleep(wait_time)
                    continue
                return None, False, error_msg

            except APIConnectionError as e:
                error_msg = f"LLM API connection error: {str(e)}"
                logger.warning(f"{error_msg}, attempt {attempt + 1}/{self.max_retries}")
                if attempt < self.max_retries - 1:
                    wait_time = self.retry_delay * (2 ** attempt)  # Exponential backoff
                    logger.info(f"Waiting {wait_time} seconds before retry...")
                    time.sleep(wait_time)
                    continue
                return None, False, error_msg

            except APIError as e:
                error_msg = f"LLM API error: {str(e)}"
                logger.error(f"{error_msg}, attempt {attempt + 1}/{self.max_retries}")
                if attempt < self.max_retries - 1:
                    wait_time = self.retry_delay * (2 ** attempt)  # Exponential backoff
                    logger.info(f"Waiting {wait_time} seconds before retry...")
                    time.sleep(wait_time)
                    continue
                return None, False, error_msg

            except Exception as e:
                error_msg = f"LLM API error: {str(e)}"
                logger.error(f"{error_msg}, attempt {attempt + 1}/{self.max_retries}")
                if attempt < self.max_retries - 1:
                    wait_time = self.retry_delay * (2 ** attempt)  # Exponential backoff
                    logger.info(f"Waiting {wait_time} seconds before retry...")
                    time.sleep(wait_time)
                    continue
                return None, False, error_msg

        return None, False, "Max retries exceeded"
