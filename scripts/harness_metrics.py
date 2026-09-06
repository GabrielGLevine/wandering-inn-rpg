#!/usr/bin/env python3
"""Measure loaded guidance and explicit session logs; emit aggregate counts only."""
from __future__ import annotations

import argparse
import datetime
import json
from pathlib import Path


def count_text(text, encode=None):
    result = {'bytes': len(text.encode()), 'characters': len(text), 'words': len(text.split())}
    if encode:
        result['o200k_proxy_tokens'] = len(encode(text))
    return result


def guidance(root, encode=None):
    files = [root / 'AGENTS.md', root / 'wandering_inn_game/AGENTS.md']
    files += sorted((root / '.agents/skills').glob('*/SKILL.md'))
    missing = [str(path.relative_to(root)) for path in files if not path.is_file()]
    if missing or len(files) == 2:
        raise ValueError('incomplete guidance root: ' + ', '.join(missing))
    bodies = [path.read_text() for path in files]
    result = count_text('\n'.join(bodies), encode)
    result['files'] = len(files)
    result['raw_file_bytes'] = sum(path.stat().st_size for path in files)
    references = sorted((root / '.agents/skills').glob('*/references/**/*'))
    result['conditional_reference_bytes'] = sum(p.stat().st_size for p in references if p.is_file())
    return result


def rendered_prompt(path, encode=None):
    messages = json.loads(path.read_text())
    if not isinstance(messages, list):
        raise ValueError('expected codex debug prompt-input JSON array')
    bodies = [block['text'] for message in messages for block in message.get('content', [])
              if isinstance(block.get('text'), str)]
    if not bodies or not any(body.strip() for body in bodies):
        raise ValueError('prompt contains no measurable text blocks')
    result = count_text('\n'.join(bodies), encode)
    result['text_blocks'] = len(bodies)
    return result


def timestamp(value):
    return datetime.datetime.fromisoformat(value.replace('Z', '+00:00')).timestamp()


def response_usage(paths):
    totals = {key: 0 for key in ('input_tokens', 'cached_input_tokens', 'output_tokens',
                                'reasoning_output_tokens', 'total_tokens')}
    seen, sessions = set(), set()
    responses = inherited = malformed = unattributed = 0
    for path in paths:
        session_id, started = None, None
        usable = 0
        for line in path.open():
            try:
                event = json.loads(line)
                payload = event.get('payload', {})
                if event.get('type') == 'session_meta':
                    session_id = payload.get('id') or payload.get('session_id')
                    started = timestamp(payload['timestamp'])
                    if not session_id:
                        raise ValueError('session metadata lacks ID')
                    sessions.add(session_id)
                    continue
                if event.get('type') != 'event_msg' or payload.get('type') != 'token_count':
                    continue
                if not session_id or started is None:
                    raise ValueError('token event without session metadata')
                if timestamp(event['timestamp']) < started:
                    inherited += 1
                    continue
                info = payload.get('info') or {}
                last, cumulative = info.get('last_token_usage'), info.get('total_token_usage')
                if not isinstance(last, dict) or not isinstance(cumulative, dict):
                    continue
                for sample in (last, cumulative):
                    for name in ('input_tokens', 'output_tokens', 'total_tokens'):
                        if type(sample.get(name)) is not int or sample[name] < 0:
                            raise ValueError('usage requires nonnegative integer token counts')
                    if sample['total_tokens'] < sample['input_tokens'] + sample['output_tokens']:
                        raise ValueError('usage total is smaller than input plus output')
                if not last['total_tokens']:
                    continue
                if cumulative['total_tokens'] < last['total_tokens']:
                    raise ValueError('cumulative usage is smaller than response usage')
                key = (session_id, json.dumps(cumulative, sort_keys=True))
                if key in seen:
                    usable += 1
                    continue
                values = {name: last.get(name, 0) for name in totals}
                if any(type(value) is not int or value < 0 for value in values.values()):
                    raise ValueError('negative token usage')
                seen.add(key)
                responses += 1
                usable += 1
                unattributed += last['total_tokens'] - last['input_tokens'] - last['output_tokens']
                for name, value in values.items():
                    totals[name] += value
            except (ValueError, TypeError, KeyError, AttributeError):
                malformed += 1
        if not usable:
            raise ValueError('session input contains no usable own response usage')
    if malformed:
        raise ValueError('session input contains malformed records; refusing partial accounting')
    return {'sessions': len(sessions), 'responses': responses,
            'skipped_inherited_events': inherited, 'malformed_events': malformed,
            'usage': totals, 'unattributed_tokens': unattributed,
            'scope': 'Distinct cumulative snapshots after session creation; sums last_token_usage. '
                     'Native total-only events retain explicit unattributed tokens. Does not estimate billing.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path)
    parser.add_argument('--prompt', type=Path)
    parser.add_argument('--session', type=Path, action='append', default=[])
    parser.add_argument('--tokenizer', action='store_true', help='optional tiktoken o200k_base proxy')
    args = parser.parse_args()
    encode = None
    if args.tokenizer:
        import tiktoken
        encode = tiktoken.get_encoding('o200k_base').encode
    result = {}
    if args.root:
        result['guidance_entrypoints'] = guidance(args.root, encode)
    if args.prompt:
        result['rendered_prompt_text'] = rendered_prompt(args.prompt, encode)
    if args.session:
        result['response_usage'] = response_usage(args.session)
    if not result:
        parser.error('provide --root, --prompt, or --session')
    result['limits'] = 'Rendered text excludes hidden system/tool definitions. Tokenizer counts are proxies; '
    result['limits'] += 'context reductions do not establish end-to-end token or cost savings.'
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
