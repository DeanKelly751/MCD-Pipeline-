import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { CodeEditor, Language } from '@patternfly/react-code-editor';
import { Button, FileUpload } from '@patternfly/react-core';
import YAML from 'yaml';

function YamlUpload(props) {
  const [value, setValue] = useState('');
  const [filename, setFilename] = useState('');

  const handleFileInputChange = (_, file) => {
    setFilename(file.name);
    const reader = new FileReader();
    reader.onload = () => setValue(reader.result);
    reader.readAsText(file);
  };

  const isValidYaml = value => {
    try {
      YAML.parse(value);
      return true;
    } catch (e) {
      return false;
    }
  }

  const handleDataChange = (_event, value) => {
    setValue(value);
  };

  const handleInputChange = (value) => {
    setValue(value);
  };

  const handleClear = _event => {
    setFilename('');
    setValue('');
  };

  const navigate = useNavigate();
  function submit() {
    navigate('/yaml', { state: YAML.parse(value) });
  }

  return <>
    <CodeEditor
      code={value}
      onChange={handleInputChange}
      isLineNumbersVisible
      isLanguageLabelVisible
      language={Language.yaml}
      height="400px"
    />
    <FileUpload
      value={value}
      filename={filename}
      filenamePlaceholder="Drag and drop a file or upload one"
      onFileInputChange={handleFileInputChange}
      onDataChange={handleDataChange}
      onClearClick={handleClear}
      allowEditingUploadedText={false}
    />
<Button
  isDisabled={!isValidYaml(value)}
  variant="primary"
  onClick={() => {
    submit();
  }}
>
  Continue
</Button>
  </>;
}

export default YamlUpload;