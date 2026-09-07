export function stageResultFailures(result, name, expectedSteps) {
 const failures = [];
 if (!Number.isInteger(expectedSteps) || expectedSteps <= 0) failures.push('expected nonempty stage');
 if (result?.passed !== true || result?.aborted !== false) failures.push('stage did not finish successfully');
 if (!Array.isArray(result?.failures) || result.failures.length !== 0) failures.push('stage failures missing or nonempty');
 if (result?.script !== `res://qa/scripts/lifecycle_${name}.json`) failures.push('wrong stage script');
 if (result?.steps_total !== expectedSteps || result?.steps_run !== expectedSteps) failures.push('stage did not run every expected step');
 return failures;
}

export function isKnownRendererDiagnostic(diagnostic) {
 if (!['warning', 'log'].includes(diagnostic.type)) return false;
 return /^\[\.WebGL-0x[0-9a-fA-F]+\]GL Driver Message \(OpenGL, Performance, GL_CLOSE_PATH_NV, High\): GPU stall due to ReadPixels(?: \(this message will no longer repeat\))?$/.test(diagnostic.text)
  || /^(?:WARNING: )?ImageLoaderSVG: Target canvas dimensions 51500[×x]51500 \(with scale 1\.00\) exceed the max supported dimensions 16384[×x]16384\. The target canvas will be scaled down\.$/.test(diagnostic.text);
}
