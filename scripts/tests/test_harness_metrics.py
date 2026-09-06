"""Prevent duplicate/inherited usage from inflating harness comparisons."""
import importlib.util
import json
from pathlib import Path

SPEC = importlib.util.spec_from_file_location('metrics', Path(__file__).parents[1] / 'harness_metrics.py')
METRICS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(METRICS)


def test_usage_uses_own_increments_and_deduplicates_repeated_files(tmp_path):
    def event(time, last, cumulative):
        return {'type': 'event_msg', 'timestamp': time, 'payload': {'type': 'token_count', 'info': {
            'last_token_usage': {'input_tokens': last, 'output_tokens': 0, 'total_tokens': last},
            'total_token_usage': {'input_tokens': cumulative, 'output_tokens': 0, 'total_tokens': cumulative}}}}
    rows = [{'type': 'session_meta', 'payload': {'id': 'child', 'timestamp': '2026-09-06T12:00:00Z'}},
            event('2026-09-06T11:59:00Z', 900, 9000),
            event('2026-09-06T12:01:00Z', 10, 9010),
            event('2026-09-06T12:01:01Z', 10, 9010),
            event('2026-09-06T12:02:00Z', 20, 9030)]
    path = tmp_path / 'session.jsonl'
    path.write_text('\n'.join(json.dumps(row) for row in rows))
    result = METRICS.response_usage([path, path])
    assert result['responses'] == 2
    assert result['usage']['input_tokens'] == 30
    assert result['sessions'] == 1
    assert result['skipped_inherited_events'] == 2
    import pytest
    path.write_text(path.read_text() + '\nmalformed')
    with pytest.raises(ValueError, match='partial accounting'):
        METRICS.response_usage([path])


def test_prompt_counts_only_model_visible_text(tmp_path):
    path = tmp_path / 'prompt.json'
    path.write_text(json.dumps([{'id': 'ignored', 'content': [
        {'type': 'input_text', 'text': 'abc'}, {'type': 'input_image', 'image_url': 'not text'}]}]))
    result = METRICS.rendered_prompt(path)
    assert result['characters'] == 3
    assert result['text_blocks'] == 1


def test_unusable_measurements_fail_instead_of_claiming_zero(tmp_path):
    import pytest
    path = tmp_path / 'bad.jsonl'
    for body in ('', 'not json', '{}', '{"type":"session_meta","payload":{}}'):
        path.write_text(body)
        with pytest.raises(ValueError, match='no usable'):
            METRICS.response_usage([path])
    path.write_text('[]')
    with pytest.raises(ValueError, match='no measurable'):
        METRICS.rendered_prompt(path)


def test_empty_usage_dictionaries_do_not_count_as_a_zero_token_response(tmp_path):
    import pytest
    path = tmp_path / 'empty-usage.jsonl'
    rows = [
        {'type': 'session_meta', 'payload': {'id': 'child', 'timestamp': '2026-09-06T12:00:00Z'}},
        {'type': 'event_msg', 'timestamp': '2026-09-06T12:01:00Z', 'payload': {
            'type': 'token_count', 'info': {'last_token_usage': {}, 'total_token_usage': {}}}}]
    path.write_text('\n'.join(json.dumps(row) for row in rows))
    with pytest.raises(ValueError, match='no usable'):
        METRICS.response_usage([path])


def test_native_total_only_event_preserves_unattributed_tokens(tmp_path):
    path = tmp_path / 'total-only.jsonl'
    usage = {'input_tokens': 0, 'output_tokens': 0, 'total_tokens': 16229}
    rows = [
        {'type': 'session_meta', 'payload': {'id': 'native', 'timestamp': '2026-09-06T12:00:00Z'}},
        {'type': 'event_msg', 'timestamp': '2026-09-06T12:01:00Z', 'payload': {
            'type': 'token_count', 'info': {'last_token_usage': usage, 'total_token_usage': usage}}}]
    path.write_text('\n'.join(json.dumps(row) for row in rows))
    result = METRICS.response_usage([path])
    assert result['usage']['total_tokens'] == 16229
    assert result['unattributed_tokens'] == 16229
