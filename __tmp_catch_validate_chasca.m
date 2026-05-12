try
    run('__tmp_validate_chasca.m');
catch ME
    disp(getReport(ME,'extended','hyperlinks','off'));
end
