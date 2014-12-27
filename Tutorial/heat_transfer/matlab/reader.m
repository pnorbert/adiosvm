function reader (file)

    % f=adiosopen(file);
    f=adiosopen(file, 'Verbose',0);

    % list metadata of all variables
    for i=1:length(f.Groups.Variables)
        f.Groups.Variables(i)
    end

    % read in the data of T
    data=adiosread(f.Groups,'T');

    adiosclose(f)

    % export the last variable in the file as 'T' in matlab
    assignin('base','T',data);

