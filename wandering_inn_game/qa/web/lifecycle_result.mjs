export function stageResultFailures(result, name, expectedSteps) {
 const failures = [];
 if (!Number.isInteger(expectedSteps) || expectedSteps <= 0) failures.push('expected nonempty stage');
 if (result?.passed !== true || result?.aborted !== false) failures.push('stage did not finish successfully');
 if (!Array.isArray(result?.failures) || result.failures.length !== 0) failures.push('stage failures missing or nonempty');
 if (result?.script !== `res://qa/scripts/lifecycle_${name}.json`) failures.push('wrong stage script');
 if (result?.steps_total !== expectedSteps || result?.steps_run !== expectedSteps) failures.push('stage did not run every expected step');
 return failures;
}
