import localUnitTest from './LocalUnit.test';
import platformServiceUnitTest from './PlatformService.test';

export default function testsuite() {
  localUnitTest();
  platformServiceUnitTest();
}